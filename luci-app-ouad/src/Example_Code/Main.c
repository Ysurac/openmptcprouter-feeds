/*
 * Main.c
 *
 *  Created on  : Sep 6, 2017
 *  Author      : Vinay Divakar
 *  Description : Example usage of the SSD1306 Driver API's
 *  Website     : www.deeplyembedded.org
 */

/* Lib Includes */
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>

/* Header Files */
#include "I2C.h"
#include "SSD1306_OLED.h"
#include "example_app.h"

/* Oh Compiler-Please leave me as is */
volatile unsigned char flag = 0;

/* Alarm Signal Handler */
void ALARMhandler(int sig)
{
    /* Set flag */
    flag = 5;
}

void BreakDeal(int sig)
{
    clearDisplay();
    usleep(1000000);
    Display();
    exit(0);
}

int main(int argc, char* argv[])
{
    char *eth=argv[1];
    char *path=argv[2];

    if(path == NULL)
        path = I2C_DEV0_PATH;

    /* Initialize I2C bus and connect to the I2C Device */
    if(init_i2c_dev(path, SSD1306_OLED_ADDR) == 0)
    {
        printf("I2C: Bus Connected to SSD1306\r\n");
    }
    else
    {
        printf("I2C: OOPS! Something Went Wrong\r\n");
        exit(1);
    }

    /* Register the Alarm Handler */
    signal(SIGALRM, ALARMhandler);
    signal(SIGINT, BreakDeal);
    //signal(SIGTERM, BreakDeal);

    /* Run SDD1306 Initialization Sequence */
/*    if (needinit==1)
        display_Init_seq();

    if (rotate==1)
        display_rotate();
    else
        display_normal();
*/
    /* Clear display */
    clearDisplay();

    // draw a single pixel
//    drawPixel(0, 1, WHITE);
//    Display();
//    usleep(1000000);
//    clearDisplay();

    // draw many lines
    while(1){
        //setCursor(0,0);
        setTextColor(WHITE);

        testintfstatus(FULL, 0);
        display_bitmap_uploaddownload();
        testnetspeed(SPLIT, 120);
        testvpsip(FULL, 52);
        Display();
        usleep(5000000);
        clearDisplay();
        testinfo1();
        Display();
        usleep(1000000);
        clearDisplay();
        testinfo2();
        Display();
        usleep(800000);
        clearDisplay();
        testinfo3();
        Display();
        usleep(200000);
        clearDisplay();
    }
}
