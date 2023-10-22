/*
 * Main.c
 *
 *  Created on  : Sep 6, 2017
 *  Author      : Vinay Divakar
 *  Description : Example usage of the SSD1306 Driver API's
 *  Website     : www.deeplyembedded.org
 */

/* Lib Includes */
#include <getopt.h>
#include <libconfig.h>
#include <limits.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

/* Header Files */
#include "I2C.h"
#include "SSD1306_OLED.h"
#include "example_app.h"

#define PROG_VERSION "1.1"
#define NETSPEED_INTERVAL 1000000
#define DISPLAY_INTERVAL 1000000
#define TINY_INTERVAL 50000
#define TIME_CHECK_INTERVAL_SHORT 1000000
#define TIME_CHECK_INTERVAL_LONG 3000000

struct st_config {
	unsigned int disp_date;
	unsigned int disp_ip;
	char *ip_if_name;
	unsigned int disp_cpu_temp;
	unsigned int disp_cpu_freq;
	unsigned int disp_net_speed;
	char *speed_if_name;
	unsigned int interval;
	unsigned int draw_line;
	unsigned int draw_rect;
	unsigned int fill_rect;
	unsigned int draw_circle;
	unsigned int draw_round_rect;
	unsigned int fill_round_rect;
	unsigned int draw_triangle;
	unsigned int fill_triangle;
	unsigned int disp_bitmap;
	unsigned int disp_invert_normal;
	unsigned int draw_bitmap_eg;
	unsigned int scroll;
	char *scroll_text;
	char *i2c_dev_path;
	unsigned int rotate;
	unsigned int need_init;
	int from;
	int to;
};

/* Oh Compiler-Please leave me as is */
volatile unsigned char flag = 0;

/** Shared variable by the threads */
static unsigned long int __shared_rx_speed = 0;
static unsigned long int __shared_tx_speed = 0;
static int __force_quit = 0;

/** Mutual exclusion of the shared variable */
static pthread_mutex_t __control_speed_vars =
    (pthread_mutex_t)PTHREAD_MUTEX_INITIALIZER;

static pthread_mutex_t __control_oled =
    (pthread_mutex_t)PTHREAD_MUTEX_INITIALIZER;

/* thread id */
static pthread_t tid_speed_calc = 0;
static pthread_t tid_display = 0;

static void printHelp() {
	printf(
	    "\n\
Usage: oled [options] ...\n\
Options:\n\
  --help or -h                      Display this information.\n\
  --version or -v                   Display compiler version information.\n\
\n\
  --config=file or -c file          Specify configuration file.\n\
\n\
  --i2cDevPath=path or -d path      Specify the i2c device, default is /dev/i2c-0.\n\
  --from=minutes or -f minites      Specify the time(in minutes of day) to start displaying, default is 0.\n\
  --to=minutes or -t minites        Specify the time(in minutes of day) to stop displaying, default is 1440.\n\
  --neetInit or -N                  Turn on init, default is on.\n\
  --interval=n or -l n              Specify the display interval, default is 60(s).\n\
  --displayInvertNormal or -I       Turn on the invert normal mode.\n\
  --rotate or -H                    Turn on rotate.\n\
\n\
  --displayDate or -D               Turn on the date display.\n\
  --displayIp or -A                 Turn on the IP address display.\n\
  --ipIfName=ifname or -a ifname    Specify the eth device to display the ip address, default is br-lan.\n\
  --displayNetSpeed or -S           Turn on the net speed display.\n\
  --speedIfName=ifname or -s ifname Specify the eth device to display the net speed, default is eth0.\n\
  --displayCpuTemp or -T            Turn on the CPU temperature.\n\
  --displayCpuFreq or -F            Turn on the CPU frequency.\n\
\n\
  --drawLine or -L                  Turn on draw line.\n\
  --drawRect or -W                  Turn on draw rectangle.\n\
  --fillRect or -w                  Turn on fill rectangle.\n\
  --drawCircle or -C                Turn on draw circle.\n\
  --drawRoundRect or -R             Turn on draw round rectangle.\n\
  --fillRoundRect or -r             Turn on fill round rectangle.\n\
  --drawTriangle or -G              Turn on draw triangle.\n\
  --fillTriangle or -g              Turn on fill triangle.\n\
  --displayBitmap or -B             Turn on display bitmap.\n\
  --drawBitmapEg or -E              Turn on draw bitmap eg.\n\
  --scroll or -O                    Turn on scroll text.\n\
  --scrollText=text or -o text      Specify the scroll text, default is 'Hello'.\n\
\n");
}

static void printVersion() { printf("Version: %s\n", PROG_VERSION); }

static void read_conf_file(const char *filename, struct st_config *stcfg) {
	config_t cfg;
	config_init(&cfg);
	char *buff;

	if (!config_read_file(&cfg, filename)) {
		fprintf(stderr, "Error reading configuration file: %s\n",
			config_error_text(&cfg));
		config_destroy(&cfg);
		exit(EXIT_FAILURE);
	}

	config_lookup_int(&cfg, "displayDate", &stcfg->disp_date);
	config_lookup_int(&cfg, "displayIp", &stcfg->disp_ip);

	if (config_lookup_string(&cfg, "ipIfName", (const char **)&buff)) {
		sprintf(stcfg->ip_if_name, "%s", buff);
	}

	config_lookup_int(&cfg, "displayCpuTemp", &stcfg->disp_cpu_temp);
	config_lookup_int(&cfg, "displayCpuFreq", &stcfg->disp_cpu_freq);
	config_lookup_int(&cfg, "displayNetSpeed", &stcfg->disp_net_speed);

	if (config_lookup_string(&cfg, "speedIfName", (const char **)&buff)) {
		sprintf(stcfg->speed_if_name, "%s", buff);
	}

	config_lookup_int(&cfg, "interval", &stcfg->interval);
	config_lookup_int(&cfg, "drawLine", &stcfg->draw_line);
	config_lookup_int(&cfg, "drawRect", &stcfg->draw_rect);
	config_lookup_int(&cfg, "fillRect", &stcfg->fill_rect);
	config_lookup_int(&cfg, "drawCircle", &stcfg->draw_circle);
	config_lookup_int(&cfg, "drawRoundRect", &stcfg->draw_round_rect);
	config_lookup_int(&cfg, "fillRoundRect", &stcfg->fill_round_rect);
	config_lookup_int(&cfg, "drawTriangle", &stcfg->draw_triangle);
	config_lookup_int(&cfg, "fillTriangle", &stcfg->fill_triangle);
	config_lookup_int(&cfg, "displayBitmap", &stcfg->disp_bitmap);
	config_lookup_int(&cfg, "displayInvertNormal",
			  &stcfg->disp_invert_normal);
	config_lookup_int(&cfg, "drawBitmapEg", &stcfg->draw_bitmap_eg);
	config_lookup_int(&cfg, "scroll", &stcfg->scroll);

	if (config_lookup_string(&cfg, "scrollText", (const char **)&buff)) {
		sprintf(stcfg->scroll_text, "%s", buff);
	}

	if (config_lookup_string(&cfg, "i2cDevPath", (const char **)&buff)) {
		sprintf(stcfg->i2c_dev_path, "%s", buff);
	}

	config_lookup_int(&cfg, "rotate", &stcfg->rotate);
	config_lookup_int(&cfg, "needInit", &stcfg->need_init);
	config_lookup_int(&cfg, "from", &stcfg->from);
	config_lookup_int(&cfg, "to", &stcfg->to);

	config_destroy(&cfg);
}

static inline float get_uptime() {
	FILE *fp1;
	float uptime = 0, idletime = 0;
	if ((fp1 = fopen("/proc/uptime", "r")) != NULL) {
		if (fscanf(fp1, "%f %f", &uptime, &idletime))
			;
		fclose(fp1);
	}
	return uptime;
}

static void *pth_netspeed(void *args) {
	struct st_config *stcfg = (struct st_config *)args;
	char rxbytes_path[80];
	char txbytes_path[80];
	unsigned long long int llu_bytes;
	unsigned long int rx_bytes = 0, tx_bytes = 0, last_rx_bytes = 0,
			  last_tx_bytes = 0;
	unsigned long int rx_speed, tx_speed;
	FILE *fp1;
	float last_uptime, uptime;

	sprintf(rxbytes_path, "/sys/class/net/%s/statistics/rx_bytes",
		stcfg->speed_if_name);
	sprintf(txbytes_path, "/sys/class/net/%s/statistics/tx_bytes",
		stcfg->speed_if_name);
	last_uptime = get_uptime();
	while (1) {
		if (__force_quit) break;

		uptime = get_uptime();
		if ((fp1 = fopen(rxbytes_path, "r")) != NULL) {
			if (fscanf(fp1, "%llu", &llu_bytes))
				;
			fclose(fp1);
			rx_bytes = llu_bytes % ULONG_MAX;
		} else {
			last_uptime = uptime;
			usleep(NETSPEED_INTERVAL);
			continue;
		}

		if ((fp1 = fopen(txbytes_path, "r")) != NULL) {
			if (fscanf(fp1, "%llu", &llu_bytes))
				;
			fclose(fp1);
			tx_bytes = llu_bytes % ULONG_MAX;
		} else {
			last_uptime = uptime;
			usleep(NETSPEED_INTERVAL);
			continue;
		}

		if ((last_rx_bytes == 0 && last_tx_bytes == 0) ||
		    (rx_bytes < last_rx_bytes) || (tx_bytes < last_tx_bytes) ||
		    (uptime <= last_uptime)) {
			last_rx_bytes = rx_bytes;
			last_tx_bytes = tx_bytes;
		} else {
			rx_speed =
			    (rx_bytes - last_rx_bytes) / (uptime - last_uptime);
			tx_speed =
			    (tx_bytes - last_tx_bytes) / (uptime - last_uptime);

			// write shared variables;
			pthread_mutex_lock(&__control_speed_vars);
			{
				__shared_rx_speed = rx_speed;
				__shared_tx_speed = tx_speed;
			}
			pthread_mutex_unlock(&__control_speed_vars);

			last_rx_bytes = rx_bytes;
			last_tx_bytes = tx_bytes;
		}
		last_uptime = uptime;
		usleep(NETSPEED_INTERVAL);
	}
}

static void *pth_display(const void *args) {
	const struct st_config *stcfg = (struct st_config *)args;
	unsigned long int rx_speed, tx_speed;
	int info_sum = stcfg->disp_date + stcfg->disp_ip +
		       stcfg->disp_cpu_freq + stcfg->disp_cpu_temp +
		       stcfg->disp_net_speed;

	/* Let the main thread work first,
	 * to ensure the timing is correct.
	 */
	usleep(TINY_INTERVAL);

	// draw many lines
	while (1) {
		if (__force_quit) break;

		if (stcfg->scroll) {
			if (__force_quit) break;

			// get oled control
			pthread_mutex_lock(&__control_oled);
			testscrolltext(stcfg->scroll_text);
			usleep(DISPLAY_INTERVAL);
			clearDisplay();
			// release oled control
			pthread_mutex_unlock(&__control_oled);
		}

		if (stcfg->draw_line) {
			if (__force_quit) break;

			// get oled control
			pthread_mutex_lock(&__control_oled);
			testdrawline();
			usleep(DISPLAY_INTERVAL);
			clearDisplay();
			// release oled control
			pthread_mutex_unlock(&__control_oled);
		}

		// draw rectangles
		if (stcfg->draw_rect) {
			if (__force_quit) break;

			// get oled control
			pthread_mutex_lock(&__control_oled);
			testdrawrect();
			usleep(DISPLAY_INTERVAL);
			clearDisplay();
			// release oled control
			pthread_mutex_unlock(&__control_oled);
		}

		// draw multiple rectangles
		if (stcfg->fill_rect) {
			if (__force_quit) break;

			// get oled control
			pthread_mutex_lock(&__control_oled);
			testfillrect();
			usleep(DISPLAY_INTERVAL);
			clearDisplay();
			// release oled control
			pthread_mutex_unlock(&__control_oled);
		}

		// draw mulitple circles
		if (stcfg->draw_circle) {
			if (__force_quit) break;

			// get oled control
			pthread_mutex_lock(&__control_oled);
			testdrawcircle();
			usleep(DISPLAY_INTERVAL);
			clearDisplay();
			// release oled control
			pthread_mutex_unlock(&__control_oled);
		}

		// draw a white circle, 10 pixel radius
		if (stcfg->draw_round_rect) {
			if (__force_quit) break;

			// get oled control
			pthread_mutex_lock(&__control_oled);
			testdrawroundrect();
			usleep(DISPLAY_INTERVAL);
			clearDisplay();
			// release oled control
			pthread_mutex_unlock(&__control_oled);
		}

		// Fill the round rectangle
		if (stcfg->fill_round_rect) {
			if (__force_quit) break;

			// get oled control
			pthread_mutex_lock(&__control_oled);
			testfillroundrect();
			usleep(DISPLAY_INTERVAL);
			clearDisplay();
			// release oled control
			pthread_mutex_unlock(&__control_oled);
		}

		// Draw triangles
		if (stcfg->draw_triangle) {
			if (__force_quit) break;

			// get oled control
			pthread_mutex_lock(&__control_oled);
			testdrawtriangle();
			usleep(DISPLAY_INTERVAL);
			clearDisplay();
			// release oled control
			pthread_mutex_unlock(&__control_oled);
		}
		// Fill triangles
		if (stcfg->fill_triangle) {
			if (__force_quit) break;

			// get oled control
			pthread_mutex_lock(&__control_oled);
			testfilltriangle();
			usleep(DISPLAY_INTERVAL);
			clearDisplay();
			// release oled control
			pthread_mutex_unlock(&__control_oled);
		}

		// Display miniature bitmap
		if (stcfg->disp_bitmap) {
			if (__force_quit) break;

			// get oled control
			pthread_mutex_lock(&__control_oled);
			display_bitmap();
			Display();
			usleep(DISPLAY_INTERVAL);
			// release oled control
			pthread_mutex_unlock(&__control_oled);
		};

		// Display Inverted image and normalize it back
		if (stcfg->disp_invert_normal) {
			if (__force_quit) break;

			// get oled control
			pthread_mutex_lock(&__control_oled);
			display_invert_normal();
			clearDisplay();
			usleep(DISPLAY_INTERVAL);
			Display();
			// release oled control
			pthread_mutex_unlock(&__control_oled);
		}

		// Generate Signal after 20 Seconds

		// draw a bitmap icon and 'animate' movement
		if (stcfg->draw_bitmap_eg) {
			if (__force_quit) break;

			alarm(10);
			flag = 0;
			// get oled control
			pthread_mutex_lock(&__control_oled);
			testdrawbitmap_eg();
			clearDisplay();
			usleep(DISPLAY_INTERVAL);
			Display();
			// release oled control
			pthread_mutex_unlock(&__control_oled);
		}

		if (info_sum == 0) {
			if (__force_quit) break;

			pthread_mutex_lock(&__control_oled);
			clearDisplay();
			usleep(DISPLAY_INTERVAL);
			Display();
			pthread_mutex_unlock(&__control_oled);
			continue;
		}

		// setCursor(0,0);
		setTextColor(WHITE);

		for (int i = 1; i < stcfg->interval; i++) {
			if (__force_quit) break;

			if (info_sum == 1) {  // only one item for display
				if (stcfg->disp_date) testdate(CENTER, 8);
				if (stcfg->disp_ip)
					testip(CENTER, 8, stcfg->ip_if_name);
				if (stcfg->disp_cpu_freq)
					testcpufreq(CENTER, 8);
				if (stcfg->disp_cpu_temp)
					testcputemp(CENTER, 8);
				if (stcfg->disp_net_speed) {
					// read shared variables;
					pthread_mutex_lock(
					    &__control_speed_vars);
					{
						rx_speed = __shared_rx_speed;
						tx_speed = __shared_tx_speed;
					}
					pthread_mutex_unlock(
					    &__control_speed_vars);

					testnetspeed(SPLIT, 0, rx_speed,
						     tx_speed);
				}
				// get oled control
				pthread_mutex_lock(&__control_oled);
				Display();
				usleep(DISPLAY_INTERVAL);
				clearDisplay();
				// release oled control
				pthread_mutex_unlock(&__control_oled);
			} else if (info_sum == 2) {  // two items for display
				if (stcfg->disp_date) {
					testdate(CENTER,
						 16 * (stcfg->disp_date - 1));
				}
				if (stcfg->disp_ip) {
					testip(CENTER,
					       16 * (stcfg->disp_date +
						     stcfg->disp_ip - 1),
					       stcfg->ip_if_name);
				}
				if (stcfg->disp_cpu_freq) {
					testcpufreq(
					    CENTER,
					    16 * (stcfg->disp_date +
						  stcfg->disp_ip +
						  stcfg->disp_cpu_freq - 1));
				}
				if (stcfg->disp_cpu_temp) {
					testcputemp(
					    CENTER,
					    16 * (stcfg->disp_date +
						  stcfg->disp_ip +
						  stcfg->disp_cpu_freq +
						  stcfg->disp_cpu_temp - 1));
				}
				if (stcfg->disp_net_speed) {
					// read shared variables;
					pthread_mutex_lock(
					    &__control_speed_vars);
					{
						rx_speed = __shared_rx_speed;
						tx_speed = __shared_tx_speed;
					}
					pthread_mutex_unlock(
					    &__control_speed_vars);

					testnetspeed(
					    MERGE,
					    16 * (stcfg->disp_date +
						  stcfg->disp_ip +
						  stcfg->disp_cpu_freq +
						  stcfg->disp_cpu_temp +
						  stcfg->disp_net_speed - 1),
					    rx_speed, tx_speed);
				}
				// get oled control
				pthread_mutex_lock(&__control_oled);
				Display();
				usleep(DISPLAY_INTERVAL);
				clearDisplay();
				// release oled control
				pthread_mutex_unlock(&__control_oled);
			} else {  // more than two items for display
				if (stcfg->disp_date) {
					testdate(FULL,
						 8 * (stcfg->disp_date - 1));
				}
				if (stcfg->disp_ip) {
					testip(FULL,
					       8 * (stcfg->disp_date +
						    stcfg->disp_ip - 1),
					       stcfg->ip_if_name);
				}
				if (stcfg->disp_cpu_freq &&
				    stcfg->disp_cpu_temp) {
					testcpu(8 * (stcfg->disp_date +
						     stcfg->disp_ip));
					if (stcfg->disp_net_speed) {
						// read shared variables;
						pthread_mutex_lock(
						    &__control_speed_vars);
						{
							rx_speed =
							    __shared_rx_speed;
							tx_speed =
							    __shared_tx_speed;
						}
						pthread_mutex_unlock(
						    &__control_speed_vars);

						testnetspeed(
						    FULL,
						    8 * (stcfg->disp_date +
							 stcfg->disp_ip + 1 +
							 stcfg->disp_net_speed -
							 1),
						    rx_speed, tx_speed);
					}
				} else {
					if (stcfg->disp_cpu_freq) {
						testcpufreq(
						    FULL,
						    8 * (stcfg->disp_date +
							 stcfg->disp_ip +
							 stcfg->disp_cpu_freq -
							 1));
					}
					if (stcfg->disp_cpu_temp) {
						testcputemp(
						    FULL,
						    8 * (stcfg->disp_date +
							 stcfg->disp_ip +
							 stcfg->disp_cpu_freq +
							 stcfg->disp_cpu_temp -
							 1));
					}
					if (stcfg->disp_net_speed) {
						// read shared variables;
						pthread_mutex_lock(
						    &__control_speed_vars);
						{
							rx_speed =
							    __shared_rx_speed;
							tx_speed =
							    __shared_tx_speed;
						}
						pthread_mutex_unlock(
						    &__control_speed_vars);

						testnetspeed(
						    FULL,
						    8 * (stcfg->disp_date +
							 stcfg->disp_ip +
							 stcfg->disp_cpu_freq +
							 stcfg->disp_cpu_temp +
							 stcfg->disp_net_speed -
							 1),
						    rx_speed, tx_speed);
					}
				}
				// get oled control
				pthread_mutex_lock(&__control_oled);
				Display();
				usleep(DISPLAY_INTERVAL);
				clearDisplay();
				// release oled control
				pthread_mutex_unlock(&__control_oled);
			}  // more than two items for display
		}	   // for
	}		   // while
}

/* Alarm Signal Handler */
void ALARMhandler(int sig) {
	/* Set flag */
	flag = 5;
}

void BreakDeal(int sig) {
	printf("Received a KILL signal, will exit in a few seconds.\n");
	__force_quit = 1;
}

static inline int get_current_minitues() {
	time_t rawtime;
	struct tm *info;
	time(&rawtime);
	info = localtime(&rawtime);
	// printf("Current local time and date: %s", asctime(info));
	// printf("Current minutues: %d\n", info->tm_hour * 60 + info->tm_min);
	return (info->tm_hour * 60 + info->tm_min);
}

static void time_switch(struct st_config *stcfg) {
	int now;
	int control_by_me = 0;
	// draw a single pixel
	//    drawPixel(0, 1, WHITE);
	//    Display();
	//    usleep(DISPLAY_INTERVAL);
	//    clearDisplay();

	while (1) {
		if (__force_quit == 1) {
			if (control_by_me == 1) {
				pthread_mutex_unlock(&__control_oled);
			}
			break;
		}

		now = get_current_minitues();
		/* During the sleep period,
		 * other threads are prohibited from controlling the display,
		 * and the display content is cleared;
		 * During the non-sleep period,
		 * release the control right of the display screen.
		 */
		if (stcfg->from != stcfg->to &&
		    (now < stcfg->from || now >= stcfg->to)) {
			if (control_by_me == 0) {
				int i;
				int repeat_clear_times = 3;

				// get oled control
				pthread_mutex_lock(&__control_oled);
				control_by_me = 1;

				/* Sometimes, clearing the screen once cannot be
				 * completely cleared it, so it is necessary
				 * to repeat clearing the screen several times.
				 */
				for(i = 0; i < repeat_clear_times; i++) {
					clearDisplay();
					usleep(DISPLAY_INTERVAL);
					Display();
				}
			}
			usleep(TIME_CHECK_INTERVAL_LONG);
		} else {
			if (control_by_me == 1) {
				// release oled control
				pthread_mutex_unlock(&__control_oled);
				control_by_me = 0;
			}
			usleep(TIME_CHECK_INTERVAL_SHORT);
		}
	}
}

int main(int argc, char *argv[]) {
	int option;
	int option_index = 0;
	int effect_sum, info_sum;
	char *config_file = NULL;
	struct st_config *stcfg;

	static struct option long_options[] = {
	    {"config", required_argument, 0, 'c'},
	    {"help", no_argument, 0, 'h'},
	    {"version", no_argument, 0, 'v'},
	    {"displayDate", no_argument, 0, 'D'},
	    {"displayIp", no_argument, 0, 'A'},
	    {"ipIfName", required_argument, 0, 'a'},
	    {"displayNetSpeed", no_argument, 0, 'S'},
	    {"speedIfName", required_argument, 0, 's'},
	    {"displayCpuTemp", no_argument, 0, 'T'},
	    {"displayCpuFreq", no_argument, 0, 'F'},
	    {"displayInvertNormal", no_argument, 0, 'I'},
	    {"interval", required_argument, 0, 'l'},
	    {"drawLine", no_argument, 0, 'L'},
	    {"drawRect", no_argument, 0, 'W'},
	    {"fillRect", no_argument, 0, 'w'},
	    {"drawCircle", no_argument, 0, 'C'},
	    {"drawRoundRect", no_argument, 0, 'R'},
	    {"fillRoundRect", no_argument, 0, 'r'},
	    {"drawTriangle", no_argument, 0, 'G'},
	    {"fillTriangle", no_argument, 0, 'g'},
	    {"displayBitmap", no_argument, 0, 'B'},
	    {"drawBitmapEg", no_argument, 0, 'E'},
	    {"scroll", no_argument, 0, 'O'},
	    {"scrollText", required_argument, 0, 'o'},
	    {"i2cDevPath", required_argument, 0, 'd'},
	    {"rotate", no_argument, 0, 'H'},
	    {"needInit", no_argument, 0, 'N'},
	    {"from", required_argument, 0, 'f'},
	    {"to", required_argument, 0, 't'},
	    {0, 0, 0, 0}};

	stcfg = malloc(sizeof(struct st_config));
	memset(stcfg, 0, sizeof(struct st_config));

	/* set default value for config */
	stcfg->need_init = 1;
	stcfg->interval = 60;
	stcfg->from = 0;
	stcfg->to = 1440;

	stcfg->ip_if_name = malloc(sizeof(char) * 20);
	sprintf(stcfg->ip_if_name, "br-lan");

	stcfg->speed_if_name = malloc(sizeof(char) * 20);
	sprintf(stcfg->speed_if_name, "eth0");

	stcfg->scroll_text = malloc(sizeof(char) * 100);
	sprintf(stcfg->scroll_text, "Hello");

	stcfg->i2c_dev_path = malloc(sizeof(char) * 20);
	sprintf(stcfg->i2c_dev_path, "%s", I2C_DEV0_PATH);
	/* The end of set default value for config */

	while ((option = getopt_long(argc, argv,
				     "c:hvDAa:Ss:TFIl:LWwCRrGgBEOo:d:HNf:t:",
				     long_options, &option_index)) != -1) {
		switch (option) {
			case 'c':
				config_file = optarg;
				break;
			case 'h':
				printHelp();
				exit(EXIT_SUCCESS);
			case 'v':
				printVersion();
				exit(EXIT_SUCCESS);
			case '?':
				// Invalid option or missing argument
				exit(EXIT_FAILURE);
			default:
				// Handle other parameters
				break;
		}
	}

	if (config_file != NULL) {
		/* Read parameters from the configuration file */
		read_conf_file(config_file, stcfg);
	}

	/* Update config from the command params */
	optind = 0;
	while ((option = getopt_long(argc, argv,
				     "c:hvDAa:Ss:TFIl:LWwCRrGgBEOo:d:HNf:t:",
				     long_options, &option_index)) != -1) {
		switch (option) {
			case 'D':
				stcfg->disp_date = 1;
				break;
			case 'A':
				stcfg->disp_ip = 1;
				break;
			case 'a':
				sprintf(stcfg->ip_if_name, "%s", optarg);
				break;
			case 'S':
				stcfg->disp_net_speed = 1;
				break;
			case 's':
				sprintf(stcfg->speed_if_name, "%s", optarg);
				break;
			case 'T':
				stcfg->disp_cpu_temp = 1;
				break;
			case 'F':
				stcfg->disp_cpu_freq = 1;
				break;
			case 'I':
				stcfg->disp_invert_normal = 1;
				break;
			case 'l':
				stcfg->interval = atoi(optarg);
				break;
			case 'L':
				stcfg->draw_line = 1;
				break;
			case 'W':
				stcfg->draw_rect = 1;
				break;
			case 'w':
				stcfg->fill_rect = 1;
				break;
			case 'C':
				stcfg->draw_circle = 1;
				break;
			case 'R':
				stcfg->draw_round_rect = 1;
				break;
			case 'r':
				stcfg->fill_round_rect = 1;
				break;
			case 'G':
				stcfg->draw_triangle = 1;
				break;
			case 'g':
				stcfg->fill_triangle = 1;
				break;
			case 'B':
				stcfg->disp_bitmap = 1;
				break;
			case 'E':
				stcfg->draw_bitmap_eg = 1;
				break;
			case 'O':
				stcfg->scroll = 1;
				break;
			case 'o':
				sprintf(stcfg->scroll_text, "%s", optarg);
				break;
			case 'd':
				sprintf(stcfg->i2c_dev_path, "%s", optarg);
				break;
			case 'H':
				stcfg->rotate = 1;
				break;
			case 'N':
				stcfg->need_init = 1;
				break;
			case 'f':
				stcfg->from = atoi(optarg);
				break;
			case 't':
				stcfg->to = atoi(optarg);
				break;
			default:
				// Handle other parameters
				break;
		}
	}

	/* Check the items that can be displayed */
	effect_sum = stcfg->scroll + stcfg->draw_line + stcfg->draw_rect +
		     stcfg->fill_rect + stcfg->draw_circle +
		     stcfg->draw_round_rect + stcfg->fill_round_rect +
		     stcfg->draw_triangle + stcfg->fill_triangle +
		     stcfg->disp_bitmap + stcfg->disp_invert_normal +
		     stcfg->draw_bitmap_eg;
	info_sum = stcfg->disp_date + stcfg->disp_ip + stcfg->disp_cpu_freq +
		   stcfg->disp_cpu_temp + stcfg->disp_net_speed;
	if (effect_sum == 0 && info_sum == 0) {
		printf(
		    "Nothing to display, check cfg file or cmd line args, "
		    "bye!\n");
		exit(EXIT_SUCCESS);
	}

	/* Check the legality of parameters from and parameters to */
	if (stcfg->from < 0 || stcfg->from > 1440) {
		stcfg->from = 0;
	}

	if (stcfg->to <= 0 || stcfg->to > 1440) {
		stcfg->to = 1440;
	}

	if (stcfg->from > stcfg->to) {
		int temp = stcfg->from;
		stcfg->from = stcfg->to;
		stcfg->to = temp;
	}

	/* Initialize I2C bus and connect to the I2C Device */
	if (init_i2c_dev(stcfg->i2c_dev_path, SSD1306_OLED_ADDR) == 0) {
		printf("Successfully connected to I2C device: %s\n",
		       stcfg->i2c_dev_path);
	} else {
		printf("Oops! There seems to be something wrong: %s\n",
		       stcfg->i2c_dev_path);
		exit(EXIT_FAILURE);
	}

	/* Run SDD1306 Initialization Sequence */
	if (stcfg->need_init == 1) display_Init_seq();

	if (stcfg->rotate == 1)
		display_rotate();
	else
		display_normal();

	clearDisplay();

	/* Create a network speed calculation thread */
	if (stcfg->disp_net_speed == 1 &&
	    strcmp(stcfg->speed_if_name, "") != 0) {
		pthread_create(&tid_speed_calc, NULL, (void *)pth_netspeed,
			       (void *)stcfg);
	}

	/* Create a display consumer thread */
	pthread_create(&tid_display, NULL, (void *)pth_display, (void *)stcfg);

	/* Register the Alarm Handler */
	signal(SIGALRM, ALARMhandler);
	signal(SIGINT, BreakDeal);
	signal(SIGTERM, BreakDeal);

	/* Time switch control function */
	time_switch(stcfg);

	/* Release resources and exit the program */
	if (tid_speed_calc != 0) {
		pthread_join(tid_speed_calc, NULL);
	}

	if (tid_display != 0) {
		pthread_join(tid_display, NULL);
	}

	pthread_mutex_destroy(&__control_speed_vars);
	pthread_mutex_destroy(&__control_oled);

	clearDisplay();
	usleep(TINY_INTERVAL);
	Display();
	Close_I2C();

	free(stcfg->scroll_text);
	free(stcfg->ip_if_name);
	free(stcfg->speed_if_name);
	free(stcfg->i2c_dev_path);
	free(stcfg);

	exit(EXIT_SUCCESS);
}
