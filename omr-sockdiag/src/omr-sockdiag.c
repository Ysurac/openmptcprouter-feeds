/*
 * omr-sockdiag -- dump established TCP sockets (with tcp_info) as JSON by
 * talking to the kernel directly over NETLINK_SOCK_DIAG (the same
 * INET_DIAG protocol iproute2's "ss" uses internally) -- no ss/ip binary
 * spawned, no text-format parsing.
 *
 * This replaces "ss -tin [src <ip>]" + awk/Lua-regex parsing used by
 * omr-metrics' 040-metrics post-tracking hook and luci-app-mptcp's
 * luci.mptcp rpcd script to read per-MPTCP-subflow TCP stats (each
 * subflow is a regular kernel TCP socket sourced from a WAN's local IP,
 * so this is effectively a "per-subflow stats" query).
 *
 * Usage: omr-sockdiag [-4] [-6] [-s <src-ip>] [-b true|false]
 *   -4        restrict to IPv4 sockets
 *   -6        restrict to IPv6 sockets
 *   -s <ip>   only include sockets whose local address equals <ip>
 *             (also narrows the family search to whichever family <ip>
 *             parses as, unless -4/-6 already narrowed it further)
 *   -b <bool> stamp a caller-supplied "backup":true/false onto every
 *             emitted object (this tool has no MPTCP/endpoint awareness of
 *             its own -- the caller looks that up separately, e.g. via
 *             "ip mptcp endpoint show", and passes the answer through)
 *   (default: both families, no source filter, no "backup" field)
 *
 * Output: a JSON array on stdout, one object per matching ESTABLISHED TCP
 * socket. Always prints a syntactically valid array ("[]" when nothing
 * matches, including when the kernel query itself fails) and exits 0 --
 * callers should treat "no data" the same as "feature unavailable", the
 * same graceful-degradation convention the shell/Lua callers already use
 * for every other collector (a missing tool/interface just leaves fields
 * null rather than aborting the whole metrics cycle).
 */

#include <arpa/inet.h>
#include <errno.h>
#include <linux/inet_diag.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>
#include <linux/sock_diag.h>
#include <linux/tcp.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/uio.h>
#include <unistd.h>

/* Not exposed via any uapi header (kernel-internal net/tcp_states.h), but
 * this numbering is long-stable ABI -- iproute2/ss and netstat both hardcode
 * it the same way. */
#define TCP_ESTABLISHED_STATE 1

struct filter {
	int want_v4;
	int want_v6;
	int has_src;
	struct in_addr src4;
	struct in6_addr src6;
};

static int first_json = 1;
/* Set via -b: an opaque, caller-supplied "backup" boolean stamped onto every
 * emitted object. This tool has no idea what an MPTCP endpoint or a backup
 * flag is -- it just knows sockets -- but the caller (which already looked
 * up the WAN's endpoint via "ip mptcp endpoint show") can pass the answer
 * straight through, so every subflow row carries it without any of our
 * callers needing to text-splice JSON they didn't generate. NULL = omit. */
static const char *backup_flag = NULL;

static int send_dump_request(int fd, int family)
{
	struct {
		struct nlmsghdr nlh;
		struct inet_diag_req_v2 r;
	} req;

	memset(&req, 0, sizeof(req));
	req.nlh.nlmsg_len = sizeof(req);
	req.nlh.nlmsg_type = SOCK_DIAG_BY_FAMILY;
	req.nlh.nlmsg_flags = NLM_F_REQUEST | NLM_F_DUMP;
	req.nlh.nlmsg_seq = 1;
	req.r.sdiag_family = family;
	req.r.sdiag_protocol = IPPROTO_TCP;
	req.r.idiag_states = 1 << TCP_ESTABLISHED_STATE;
	/* Request INFO (tcp_info: cwnd/rtt/retrans/bytes/...), VEGASINFO
	 * (doubles as the request bit for whichever CC-specific struct
	 * applies -- vegas/dctcp/bbr, the kernel picks based on the socket's
	 * actual congestion control), and CONG (the CC algorithm name). */
	req.r.idiag_ext = (1 << (INET_DIAG_INFO - 1))
	                 | (1 << (INET_DIAG_VEGASINFO - 1))
	                 | (1 << (INET_DIAG_CONG - 1));

	struct sockaddr_nl dst;
	memset(&dst, 0, sizeof(dst));
	dst.nl_family = AF_NETLINK;

	struct iovec iov;
	iov.iov_base = &req;
	iov.iov_len = sizeof(req);

	struct msghdr msg;
	memset(&msg, 0, sizeof(msg));
	msg.msg_name = &dst;
	msg.msg_namelen = sizeof(dst);
	msg.msg_iov = &iov;
	msg.msg_iovlen = 1;

	return sendmsg(fd, &msg, 0) < 0 ? -1 : 0;
}

static const char *addr_str(int family, const __be32 *raw, char *buf, size_t buflen)
{
	inet_ntop(family == AF_INET ? AF_INET : AF_INET6, raw, buf, buflen);
	return buf;
}

static int addr_matches(const struct filter *f, int family, const __be32 *raw)
{
	if (!f->has_src)
		return 1;
	if (family == AF_INET)
		return f->want_v4 && memcmp(raw, &f->src4, sizeof(f->src4)) == 0;
	return f->want_v6 && memcmp(raw, &f->src6, sizeof(f->src6)) == 0;
}

/* Escape the bare minimum for a congestion-control algorithm name (kernel
 * module names are already a very restricted charset in practice, but never
 * trust kernel-supplied strings blindly when embedding them in JSON). */
static void print_json_string(const char *s, size_t maxlen)
{
	size_t i;
	putchar('"');
	for (i = 0; i < maxlen && s[i]; i++) {
		unsigned char c = (unsigned char)s[i];
		if (c == '"' || c == '\\')
			putchar('\\');
		if (c < 0x20)
			continue;
		putchar(c);
	}
	putchar('"');
}

static void emit_socket(const struct inet_diag_msg *m, const struct tcp_info *ti,
                         const char *cc_name, size_t cc_len,
                         const struct tcp_bbr_info *bbr)
{
	char lbuf[INET6_ADDRSTRLEN], rbuf[INET6_ADDRSTRLEN];

	addr_str(m->idiag_family, m->id.idiag_src, lbuf, sizeof(lbuf));
	addr_str(m->idiag_family, m->id.idiag_dst, rbuf, sizeof(rbuf));

	printf("%s{\"local_ip\":", first_json ? "" : ",");
	print_json_string(lbuf, sizeof(lbuf));
	printf(",\"local_port\":%u,\"remote_ip\":", ntohs(m->id.idiag_sport));
	print_json_string(rbuf, sizeof(rbuf));
	printf(",\"remote_port\":%u", ntohs(m->id.idiag_dport));
	first_json = 0;

	if (ti) {
		/* The kernel initializes ssthresh to a "no limit yet" sentinel
		 * (TCP_INFINITE_SSTHRESH, 0x7fffffff) until slow start actually
		 * ends -- iproute2's ss only prints ssthresh below 0xFFFF and
		 * omits it entirely otherwise. Match that (as "null") instead
		 * of emitting the raw sentinel: confirmed live against a real
		 * MPTCP subflow that ss's own text output silently drops this
		 * field in exactly that case, so a consumer comparing this
		 * tool's output against the ss-based fallback path would
		 * otherwise see a bogus ~2.1 billion spike for the same socket. */
		char ssthresh_buf[16];
		if (ti->tcpi_snd_ssthresh < 0xFFFF)
			snprintf(ssthresh_buf, sizeof(ssthresh_buf), "%u", ti->tcpi_snd_ssthresh);
		else
			snprintf(ssthresh_buf, sizeof(ssthresh_buf), "null");

		printf(",\"cwnd\":%u,\"ssthresh\":%s"
		       ",\"rtt\":%.3f,\"rttvar\":%.3f,\"min_rtt\":%.3f"
		       ",\"retrans\":%u,\"retrans_total\":%u"
		       ",\"bytes_sent\":%llu,\"bytes_acked\":%llu"
		       ",\"bytes_retrans\":%llu,\"bytes_received\":%llu"
		       ",\"segs_out\":%u,\"segs_in\":%u"
		       ",\"pacing_rate\":%llu,\"delivery_rate\":%llu"
		       ",\"rwnd\":%u,\"swnd\":%u",
		       ti->tcpi_snd_cwnd, ssthresh_buf,
		       ti->tcpi_rtt / 1000.0, ti->tcpi_rttvar / 1000.0,
		       ti->tcpi_min_rtt / 1000.0,
		       ti->tcpi_retransmits, ti->tcpi_total_retrans,
		       (unsigned long long)ti->tcpi_bytes_sent,
		       (unsigned long long)ti->tcpi_bytes_acked,
		       (unsigned long long)ti->tcpi_bytes_retrans,
		       (unsigned long long)ti->tcpi_bytes_received,
		       ti->tcpi_segs_out, ti->tcpi_segs_in,
		       /* tcp_info rates are bytes/sec; the JSON schema here
		        * (matching the shell/Lua callers) is bits/sec, same
		        * convention "ss"'s own "Mbps" display uses. */
		       (unsigned long long)ti->tcpi_pacing_rate * 8,
		       (unsigned long long)ti->tcpi_delivery_rate * 8,
		       /* rwnd/swnd exist per-subflow only -- there is no MPTCP
		        * connection-level (msk) receive-window field at all:
		        * struct mptcp_info (linux/mptcp.h) has none, and it isn't
		        * even netlink-reachable regardless (it's a
		        * getsockopt(SOL_MPTCP, MPTCP_INFO) structure, readable
		        * only by the owning process via its own fd, not by a
		        * separate tool enumerating sockets over netlink). */
		       ti->tcpi_rcv_wnd, ti->tcpi_snd_wnd);
	}
	if (bbr) {
		/* bbr_bw_{lo,hi} form a 64-bit byte/sec bandwidth estimate (the
		 * same "max-filtered BW" ss prints inline as "bbr:(bw:...)");
		 * bbr_min_rtt is BBR's own internally-filtered min-RTT probe
		 * (microseconds) -- distinct from tcp_info's tcpi_min_rtt above,
		 * which is the generic TCP stack's all-time min RTT sample, not
		 * BBR's actively-maintained probe-RTT estimate. */
		unsigned long long bw = ((unsigned long long)bbr->bbr_bw_hi << 32) | bbr->bbr_bw_lo;
		printf(",\"bbr_bw\":%llu,\"bbr_min_rtt\":%.3f",
		       bw * 8, bbr->bbr_min_rtt / 1000.0);
	}
	if (cc_name) {
		printf(",\"cc\":");
		print_json_string(cc_name, cc_len);
	}
	if (backup_flag)
		printf(",\"backup\":%s", backup_flag);
	printf("}");
}

static void drain_family(int fd, int family, const struct filter *f)
{
	char buf[16384];

	if (send_dump_request(fd, family) < 0)
		return;

	for (;;) {
		ssize_t len = recv(fd, buf, sizeof(buf), 0);
		if (len <= 0)
			return;

		struct nlmsghdr *nlh = (struct nlmsghdr *)buf;
		while (NLMSG_OK(nlh, len)) {
			if (nlh->nlmsg_type == NLMSG_DONE)
				return;
			if (nlh->nlmsg_type == NLMSG_ERROR)
				return;

			const struct inet_diag_msg *m = NLMSG_DATA(nlh);
			int rtalen = nlh->nlmsg_len - NLMSG_LENGTH(sizeof(*m));
			const struct tcp_info *ti = NULL;
			const char *cc_name = NULL;
			size_t cc_len = 0;
			const struct tcp_bbr_info *bbr = NULL;

			if (rtalen >= 0) {
				struct rtattr *rta = (struct rtattr *)
					(((char *)m) + NLMSG_ALIGN(sizeof(*m)));
				for (; RTA_OK(rta, rtalen); rta = RTA_NEXT(rta, rtalen)) {
					if (rta->rta_type == INET_DIAG_INFO)
						ti = (const struct tcp_info *)RTA_DATA(rta);
					else if (rta->rta_type == INET_DIAG_CONG) {
						cc_name = (const char *)RTA_DATA(rta);
						cc_len = RTA_PAYLOAD(rta);
					/* Requested via the single VEGASINFO bit (see
					 * send_dump_request) -- the kernel tags the reply
					 * with whichever CC-specific attribute type
					 * actually applies. Only BBR is handled here. */
					} else if (rta->rta_type == INET_DIAG_BBRINFO
					           && RTA_PAYLOAD(rta) >= sizeof(struct tcp_bbr_info)) {
						bbr = (const struct tcp_bbr_info *)RTA_DATA(rta);
					}
				}
			}

			if (addr_matches(f, m->idiag_family, m->id.idiag_src))
				emit_socket(m, ti, cc_name, cc_len, bbr);

			nlh = NLMSG_NEXT(nlh, len);
		}
	}
}

int main(int argc, char **argv)
{
	struct filter f;
	memset(&f, 0, sizeof(f));
	f.want_v4 = f.want_v6 = 1;

	int i;
	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "-4") == 0) {
			f.want_v4 = 1;
			f.want_v6 = 0;
		} else if (strcmp(argv[i], "-6") == 0) {
			f.want_v4 = 0;
			f.want_v6 = 1;
		} else if (strcmp(argv[i], "-s") == 0 && i + 1 < argc) {
			i++;
			f.has_src = 1;
			if (inet_pton(AF_INET, argv[i], &f.src4) == 1) {
				f.want_v6 = 0;
			} else if (inet_pton(AF_INET6, argv[i], &f.src6) == 1) {
				f.want_v4 = 0;
			} else {
				fprintf(stderr, "omr-sockdiag: invalid -s address: %s\n", argv[i]);
				printf("[]\n");
				return 0;
			}
		} else if (strcmp(argv[i], "-b") == 0 && i + 1 < argc) {
			i++;
			backup_flag = (strcmp(argv[i], "true") == 0) ? "true" : "false";
		} else {
			fprintf(stderr, "usage: omr-sockdiag [-4] [-6] [-s <src-ip>] [-b true|false]\n");
			return 2;
		}
	}

	int fd = socket(AF_NETLINK, SOCK_RAW, NETLINK_SOCK_DIAG);
	if (fd < 0) {
		/* Graceful degradation: callers treat "[]" the same as
		 * "nothing to report right now", not a hard failure. */
		printf("[]\n");
		return 0;
	}

	struct sockaddr_nl local;
	memset(&local, 0, sizeof(local));
	local.nl_family = AF_NETLINK;
	bind(fd, (struct sockaddr *)&local, sizeof(local));

	printf("[");
	if (f.want_v4)
		drain_family(fd, AF_INET, &f);
	if (f.want_v6)
		drain_family(fd, AF_INET6, &f);
	printf("]\n");

	close(fd);
	return 0;
}
