CLANG ?= clang

all:
	$(CLANG) -O2 -Wall -g -target bpf -c mptcp_bpf_red.c -o mptcp_bpf_red.o -I../../linux/tools/lib/

clean:
	rm -rf mptcp_bpf_red.ll mptcp_bpf_red.o
