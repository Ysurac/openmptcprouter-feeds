/*
 * Copyright (c) 2016  Qualcomm Atheros, Inc.
 *
 * All Rights Reserved.
 * Qualcomm Atheros Confidential and Proprietary.
 */

/**************
 *
 * Filename:    connectionmgr.c
 *
 * Purpose:     Connection Manager application
 *
 * Copyright: © 2011-2013 Sierra Wireless Inc., all rights reserved
 *
 **************/
#define _SVID_SOURCE
#include "SWIWWANCMAPI.h"
#include "displaymgmt.h"
#include "qaGobiApiWds.h"
#include "qaGobiApiQos.h"
#include <unistd.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include "qmerrno.h"

/****************************************************************
*                       DEFINES
****************************************************************/


#define SUCCESS                  0
#define FAIL                     1
#define ENTER_KEY                0x0A
#define ENTER_KEY_PRESSED        0
#define OPTION_LEN               5
#define IP_ADDRESS_LEN           15
#define IPADDREESS_OCTET_MASK    0x000000FF
#define PDP_IPV4                 0
#define IPv4_FAMILY_PREFERENCE   0x04
#define IPv6_FAMILY_PREFERENCE   0x06
#define IPv4v6_FAMILY_PREFERENCE 0x07
#define MAX_FIELD_SIZE           128
#define POWER_OFF_MODE           3
#define POWER_RESET_MODE         4

/* APN, User Name and Profile name size should be 3 greater than the actual
 * characters to be read. This will help to ensure that user should not enter
 * more than maximum allowed characters.
 */
#define MAX_APN_SIZE            104
#define MAX_PROFILE_NAME_SIZE   17
#define MAX_USER_NAME_SIZE      129
#define DEV_NODE_SZ             256
#define DEV_KEY_SZ              16
#define RESP_BUFFER_LEN         128
#define MAX_PROFILES            16
#define PROFILE_TYPE_UMTS       0
#define MIN_PROFILES            1
#define START_DATA_SEESION      1
#define STOP_DATA_SEESION       0
#define TECHNOLOGY_3GPP         1
#define TECHNOLOGY_3GPP2        2
#define TEN_SECONDS_TIMER       10
#define ERR_GENERAL             1
#define ERR_ENUM_END            34
/* Note: only two instances are supported */
#define MIN_INST_ID             0
#define MAX_INST_ID             1

#define nMaxStrLen              0xFF

#define CDMA_PROFILE_OFFSET     (100)

#define MAX_CHANNEL 255
#define OL_ATH_PARAM_SHIFT 0x1000
#define OL_ATH_PARAM_ACS_BLOCK_MODE 205
#define BLOCK_MODE 0x03

/* macros*/
#define rcprint(s, u) syslog( LOG_USER, "%s: rc = 0x%lX", s, u )
#define TRACE_MSG(log_level, fp, format,...) { \
         fprintf(fp, format, ##__VA_ARGS__); \
         fflush(fp); \
         syslog(log_level, format, ##__VA_ARGS__); }
#define MAX_LENGTH 1024

/****************************************************************
*                       DATA STRUCTURE
****************************************************************/

/* Device information structure */
typedef struct device_info_param{
  CHAR deviceNode[DEV_NODE_SZ];
  CHAR deviceKey[DEV_KEY_SZ];
}device_info_t;

/* Profile Information structure */
struct profileInformation{
    ULONG profileType;
    ULONG PDPType;
    ULONG IPAddress;
    ULONG primaryDNS;
    ULONG secondaryDNS;
    ULONG Authentication;
    CHAR  profileName[MAX_PROFILE_NAME_SIZE];
    CHAR  APNName[MAX_APN_SIZE];
    CHAR  userName[MAX_USER_NAME_SIZE];
    CHAR  password[MAX_FIELD_SIZE];
};


/* Profile indexes for profile existing on device */
struct profileIndexesInfo{
    BYTE profileIndex[MAX_PROFILES];
    BYTE totalProfilesOnDevice;
};

struct ProfileDetails{
    CHAR  connectionType[MAX_FIELD_SIZE];
    BYTE  IPFamilyPreference;
    BYTE  PDPType;
    CHAR  IPAddress[MAX_FIELD_SIZE];
    CHAR  primaryDNS[MAX_FIELD_SIZE];
    CHAR  secondaryDNS[MAX_FIELD_SIZE];
    BYTE  authenticationValue;
    CHAR  profileName[MAX_PROFILE_NAME_SIZE];
    CHAR  APNName[MAX_APN_SIZE];
    CHAR  userName[MAX_USER_NAME_SIZE];
    CHAR  password[MAX_FIELD_SIZE];
};

/* session state enumeration */
enum eSessionStates{
    eSTATE_DISCONNECTED = 1,
    eSTATE_CONNECTED,
    eSTATE_SUSPENDED,
    eSTATE_AUTHENTICATING,
};

/* Data bearer Enumeration */
enum eDataBearer{
    eBEARER_CDMA_RTT = 1,
    eBEARER_CDMA_REV_0,
    eBEARER_GPRS,
    eBEARER_WCDMA,
    eBEARER_CDMA_REV_A,
    eBEARER_EDGE,
    eBEARER_HSDPA,
    eBEARER_WCDMA_DL,
    eBEARER_HSDPA_DL,
    eBEARER_LTE,
    eBEARER_CDMA_EHRPD,
    eBEARER_HSDPA_PLUS_WCDMA,
    eBEARER_HSDAP_PLUS_HSUPA,
    eBEARER_DCHSDAP_PLUS_WCDMA,
    eBEARER_DCHSDAP_PLUS_HSUPA,
    eBEARER_HSDPA_PLUS_64QAM,
    eBEARER_HSDPA_PLUS_HSUPA,
    eBEARER_TDSCDMA,
    eBEARER_TDSCDMA_HSDPA
};

/* Dormancy status enumeration */
enum eDormancyStatus{
    eTRAFFIC_CHANNEL_DORMANT = 1,
    eTRAFFIC_CHANNEL_ACTIVE,
};

/* Radio Interface enumeration */
enum eRadioInterface{
    eNO_SERVICE,
    eCDMA_1xRTT,
    eCDMA_1xEVDO,
    eAMPS,
    eGSM,
    eUMTS,
    eWLAN,
    eGPS,
    eLTE,
};

/* Roaming Indicator enumeration */
enum eRoamingIndicator{
    eROAMING,
    eHOME,
    eROAMING_PARTNER,
};

struct DataSessionOutput{
    CHAR status[MAX_LENGTH];
    CHAR duration[MAX_LENGTH];
    CHAR manufacture_id[MAX_LENGTH];
    CHAR model_id[MAX_LENGTH];
    CHAR firmware_revisions[MAX_LENGTH];
    CHAR boot_revisions[MAX_LENGTH];
    CHAR pri_versions[MAX_LENGTH];
    CHAR prl_version[MAX_LENGTH];
    CHAR prl_preference[MAX_LENGTH];
    CHAR imsi[MAX_LENGTH];
    CHAR hardware_revision[MAX_LENGTH];
    CHAR ip_address[MAX_LENGTH];
    CHAR subnet_mask[MAX_LENGTH];
    CHAR gateway[MAX_LENGTH];
    CHAR primary_dns[MAX_LENGTH];
    CHAR secondary_dns[MAX_LENGTH];
    CHAR radio_interface[MAX_LENGTH];
    CHAR band_class[MAX_LENGTH];
    CHAR active_channel[MAX_LENGTH];
};

/****************************************************************
*                    GLOBAL DATA
****************************************************************/
/* path to sdk binary */
static char *sdkbinpath = NULL;

/* device connectivity */
static struct profileIndexesInfo indexInfo;
struct DataSessionOutput sessionOutput;
static device_info_t             devices[1] = { { {'\0'}, {'\0'} } };
static device_info_t             *pdev = &devices[0];
static BOOL                      devready = 0;
struct ssdatasession_params sumts[MAX_INST_ID+1];
struct ssdatasession_params slte[MAX_INST_ID+1];
static BYTE sessionNum = 0;
static BYTE sessionNumLte = 0;

/* Log file pointer */
FILE *fp;

/****************************************************************
*              FORWARD FUNCTION DECLARATION
****************************************************************/
static void UpdateDisplayInfo( void );
static void GetDeviceinfo( void );
static void GetNetworkDetails( void );
static void UnSubscribeCallbacks();
typedef void( *sighandler_t )( int );

/****************************************************************
*                       FUNCTIONS
****************************************************************/

/*
 * Name:     QuitApplication
 *
 * Purpose:  Closes the Application
 *
 * Params:   None
 *
 * Return:   None
 *
 * Notes:    None
 */
void QuitApplication()
{
    ULONG result = 0;
    char command[MAX_LENGTH];
    struct stat fileAttribute;

    free(sdkbinpath);
    UnSubscribeCallbacks();
    DeleteProfilesFromDevice();
    QCWWANDisconnect();
    if((stat("/usr/bin/channel_avoidance.sh", &fileAttribute)) < 0)
    {
        TRACE_MSG(LOG_ERR, fp, "/usr/bin/channel_avoidance.sh : %s\n", strerror(errno));
        return;
    }
    snprintf(command, MAX_LENGTH, "/usr/bin/channel_avoidance.sh ");
    TRACE_MSG(LOG_INFO, fp, "calling : %s", command);
    if((result = system(command)) != 0)
    {
        TRACE_MSG(LOG_ERR, fp, "channel_avoidance.sh script failed : %d\n", result);
    }
    memset(&sessionOutput, 0, sizeof(sessionOutput));
    UpdateDisplayInfo();
    TRACE_MSG( LOG_INFO, fp, "Exiting Application!!!\n" );
    fclose(fp);
    closelog();
    exit( EXIT_SUCCESS );
}

/*
 * Name:     ValidateIPAddressOctet
 *
 * Purpose:  Validates the received  octet of the IP Address.
 *
 * Params:   pIPAddressOctet - Pointer to the buffer containing IP Address
 *                             octet to be validated.
 *           len             - length of the passed buffer
 *
 * Return:   SUCCESS   - In case valid digits are there in the received octet of
 *                       the IP Address
 *           FAIL      - If invalid octet is received
 *
 * Notes:    None
 */
BYTE ValidateIPAddressOctet( CHAR* pIPAddressOctet, int len )
{
    if( len == 3)
    {
        /* If length of the octet is 3, first digit should be between 0 and 2 */
        if( ( '0' > pIPAddressOctet[0] ) ||
            ( '2' < pIPAddressOctet[0] ) )
        {
            return FAIL;
        }

        /* If first digit is 2 then second digit should not be greater than 5 */
        if( '2' == pIPAddressOctet[0] )
        {
            if( '5' < pIPAddressOctet[1] )
            {
                return FAIL;
            }

            /* If second digit is also 5 then third digit should not be greater
             * than 5.
             */
            if( '5' == pIPAddressOctet[1] )
            {
                if( '5' < pIPAddressOctet[2] )
                {
                    return FAIL;
                }
            }
        }

        if( ( '0' > pIPAddressOctet[1] ) ||
            ( '9' < pIPAddressOctet[1] ) )
        {
            return FAIL;
        }

        if( ( '0' > pIPAddressOctet[2] ) ||
            ( '9' < pIPAddressOctet[2] ) )
        {
            return FAIL;
        }
    }

    if( 2 == len )
    {
        if( ( '0' > pIPAddressOctet[0] ) ||
            ( '9' < pIPAddressOctet[0] ) )
        {
            return FAIL;
        }

        if( ( '0' > pIPAddressOctet[1] ) ||
            ( '9' < pIPAddressOctet[1] ) )
        {
            return FAIL;
        }
    }

    if( 1 == len )
    {
        if( ( '0' > pIPAddressOctet[0] ) ||
            ( '9' < pIPAddressOctet[0] ) )
        {
            return FAIL;
        }
    }
    return SUCCESS;
}

/*
 * Name:     IPUlongToDot
 *
 * Purpose:  Convert the IP address passed by the user in the form of ULONG
 *           value to a DOT format and copy it into the user buffer.
 *
 * Params:   IPAddress  - IP Address to be converted in dot notation.
 *           pIPAddress - Buffer to store IP Address converted to dot notation.
 *
 * Return:   None
 *
 * Notes:    None
 */
static void IPUlongToDot( ULONG IPAddress, char* pIPAddress )
{
    CHAR  tempBuf[5];
    BYTE  idx = 0;
    BYTE  shift = 0;
    ULONG tempIPAddress = 0;
    int   IPAddr = 0;

    for( idx = 4; idx > 0; idx-- )
    {
        shift = ( idx - 1 ) * 8;
        tempIPAddress = IPAddress >> shift;
        IPAddr = tempIPAddress & IPADDREESS_OCTET_MASK;
        sprintf( tempBuf, "%d", IPAddr );
        strcat( pIPAddress, tempBuf );
        tempIPAddress = 0;
        if( 1 >= idx )
        {
            continue;
        }
        strcat( pIPAddress, "." );
    }
}

/*
 * Name:     IPDotToUlong
 *
 * Purpose:  Convert the IP address passed by the user in dot notation to
 *           a ULONG value.
 *
 * Params:   pIPAddress - IP Address to be converted to ULONG value.
 *           pAddress   - ULONG pointer to store converted IP Address.
 *
 * Return:   SUCCESS   - In case valid IP Address is provided by the user
 *           FAIL      - In case invalid IP Address is provided by the user
 *
 * Notes:    None
 */
BYTE IPDotToUlong( char* pIPAddress, ULONG* pAddress )
{
    CHAR* pCharacterOccurence = NULL;
    int   IPAddressOctet = 0;
    BYTE  len = 0, noOfShift = 8;
    ULONG IPAddress = 0;

    /* Being here means correct no. of dots are there in the IP  address. Jump
     * to first occurrence of the dot.
     */
    pCharacterOccurence = strtok( pIPAddress,"." );
    while( NULL != pCharacterOccurence )
    {
        len = strlen( pCharacterOccurence );
        if( ( 0 == len ) || ( 3 < len ) )
        {
            #ifdef DBG
            fprintf( stderr, "Incorrect octet length : %d\n",len );
            #endif
            *pAddress = 0;
            return FAIL;
        }

        /* Check if the valid digits have been entered in IP Address */
        if( FAIL == ValidateIPAddressOctet( pCharacterOccurence, len ) )
        {
            #ifdef DBG
            fprintf( stderr, "Incorrect characters in octet : %s\n",
                              pCharacterOccurence );
            #endif
            *pAddress = 0;
            return FAIL;
        }

        IPAddressOctet = atoi( pCharacterOccurence );
        if( 255 < IPAddressOctet )
        {
            #ifdef DBG
            fprintf( stderr, "Incorrect octet value : %d\n",IPAddressOctet );
            #endif
            *pAddress = 0;
            return FAIL;
        }
        len = 0;

        /* Store the octet */
        IPAddress = ( IPAddress << noOfShift ) | IPAddressOctet;

        #ifdef DBG
        fprintf( stderr, "IP Address Octet Value: %s, Integer: %d\n",
                          pCharacterOccurence, IPAddressOctet );
        fprintf( stderr, "IP Address : %lx\n",IPAddress );
        #endif
        IPAddressOctet = 0;

        /* look for the next dot */
        pCharacterOccurence = strtok( NULL, "." );
    }

    *pAddress = IPAddress;
    #ifdef DBG
    fprintf( stderr, "Final IP Address : %lx\n",*pAddress );
    #endif
    return SUCCESS;
}

/*
 * Name:     GetIPFromUser
 *
 * Purpose:  Prompt the user to enter the IP address and copy it in the passed
 *           buffer.
 *
 * Return:   SUCCESS   - In case valid IP Address is entered by the user
 *           ENTER_KEY - If enter key is pressed by the user
 *
 * Params:   pAddressString - Name of the address to be retrieved.
 *           pIPAddress     - Buffer to receive the address from user.
 *           pAddress       - Pointer to store received IP address after
 *                            conversion from dot notation to ULONG value.
 *
 * Notes:    None
 */
ULONG GetIPFromUser( char *pAddressString, char *pIPAddress, ULONG *pAddress )
{
    int  len = 0;
    BYTE count = 0, returnCode = 0, IPAddressWrong = FALSE;
    CHAR *pCharacterOccurence = NULL, *pEndOfLine = NULL;


    len = strlen( pIPAddress );

    /* Validate the address entered by the user */
    /* Check the IP Address Length */
    if( IP_ADDRESS_LEN < len )
    {
        TRACE_MSG( LOG_ERR, fp, "Incorrect Address Length : %d\n",len );
        return -1;
    }

    /* Check if there is nothing followed by a Dot in the IP address or
     * there are two adjacent dots.
     */

    pCharacterOccurence = strchr( pIPAddress,'.' );
    while ( NULL != pCharacterOccurence )
    {
        if( ( '.'  == pCharacterOccurence[1] ) ||
            ( '\0' == pCharacterOccurence[1] ) )
        {
            TRACE_MSG( LOG_ERR, fp, "Two Adjacent dots or NULL after a dot:"\
                              "Wrong IP Address\n" );
            IPAddressWrong = TRUE;
            return -1;
        }
        count++;
        pCharacterOccurence = strchr( ( pCharacterOccurence + 1 ),'.' );
    }

    /* If there are more than three dots in the IP address */
    if( ( 3 != count ) || ( TRUE == IPAddressWrong ) )
    {
        TRACE_MSG( LOG_ERR, fp, "Incorrect No. of dots in address : %d\n",count );
        IPAddressWrong = FALSE;
        count = 0;
        return -1;
     }

     count = 0;

     /* Convert the IP address from DOT notation to ULONG */
     returnCode = IPDotToUlong( pIPAddress, pAddress );

     /* If IP Address is not correct */
     if( SUCCESS != returnCode )
     {
         TRACE_MSG( LOG_ERR, fp, "IPDotToUlong failed : %lu", returnCode );
         return -1;
     }

     return SUCCESS;
}

/*
 * Name:     DeleteProfilesFromDevice
 *
 * Purpose:  Delete all profiles from the device
 *
 * Params:   None
 *
 * Return:   None.
 *
 * Notes:    None
 */
void DeleteProfilesFromDevice()
{
    ULONG                          resultCode = 0;
    ULONG                          profileType = PROFILE_TYPE_UMTS;
    BYTE                           profileId;
    ULONG                          PDPType;
    ULONG                          IPAddress;
    ULONG                          primaryDNS;
    ULONG                          secondaryDNS;
    ULONG                          authentication;
    CHAR                           profileName[MAX_PROFILE_NAME_SIZE];
    CHAR                           APNName[MAX_APN_SIZE];
    CHAR                           Username[MAX_USER_NAME_SIZE];
    struct SLQSDeleteProfileParams profileToDelete;
    WORD                           extendedErrorCode = 0;


    /* If no profile exist on the device, return */
    if( 0 == indexInfo.totalProfilesOnDevice )
    {
        TRACE_MSG( LOG_INFO, fp, "No Profile exist on the device for deletion "\
                         "or check device connectivity\n\n");
        return;
    }

    for( profileId = 2; profileId < MAX_PROFILES; profileId++ )
    {
        resultCode = SLQSGetProfile( profileType,
                                     profileId,
                                     &PDPType,
                                     &IPAddress,
                                     &primaryDNS,
                                     &secondaryDNS,
                                     &authentication,
                                     MAX_PROFILE_NAME_SIZE,
                                     profileName,
                                     MAX_APN_SIZE,
                                     APNName,
                                     MAX_USER_NAME_SIZE,
                                     Username,
                                     &extendedErrorCode );

        /* If the profile does not exist on the device or we failed to
         * retrieve the information about the profile.
         */
        if( SUCCESS != resultCode )
        {
            return;
        }
        /* Delete the profile from the device */
        profileToDelete.profileType  = 0;
        profileToDelete.profileIndex = profileId;
        resultCode = SLQSDeleteProfile( &profileToDelete, &extendedErrorCode );

        /* If we fail to delete the profile */
        if( SUCCESS != resultCode )
        {
            TRACE_MSG( LOG_ERR, fp, "Profile Deletion Failed\nFailure cause - %lu\n"\
                             "Error Code - %d\n\n",
                             resultCode, extendedErrorCode );
            continue;
        }

        TRACE_MSG( LOG_INFO, fp, "Profile for index %d deleted successfully\n",
                          profileId );
    }
}

/*
 * Name:     CreateProfile
 *
 * Purpose:  Create the Profile with the values provided by the user.
 *
 * Params:   None
 *
 * Return:   None
 *
 * Notes:    None
 */
ULONG CreateProfile(struct ProfileDetails *profileDetails)
{
    struct profileInformation  profileInfo;
    struct CreateProfileIn     profileToCreate;
    struct CreateProfileOut    profileCreatedresult;
    ULONG                      resultCode = 0;
    BYTE                       profileType = PROFILE_TYPE_UMTS;
    BYTE                       PDPType = 0, profileindex = 0, authValue = 0;
    USHORT                     extendedErrorCode;
    CHAR                       IPAddress[MAX_FIELD_SIZE];
    BYTE                       profileTypeOut;

    /* Reset the input params */
    memset( (void *)&profileToCreate, 0, sizeof( profileToCreate ) );
    memset( (void *)&profileCreatedresult,
            0,
            sizeof( profileCreatedresult ) );
    profileToCreate.pProfileType = &profileType;
    profileindex = 0;
    extendedErrorCode = 0;
    profileCreatedresult.pProfileType  = &profileTypeOut;
    profileCreatedresult.pProfileIndex = &profileindex;
    profileCreatedresult.pExtErrorCode = &extendedErrorCode;


    /* Get PDP Type */

    if(profileDetails->PDPType > 3)
    {
        TRACE_MSG(LOG_ERR, fp, "Invalid PDPType\n");
        TRACE_MSG(LOG_INFO, fp, "Valid PDPType 0 - IPv4, 1 - PPP, 2 - IPV6, 3 - IPV4V6\n");
        return -1;
    }
    PDPType = profileDetails->PDPType;
    profileToCreate.curProfile.SlqsProfile3GPP.pPDPtype = &PDPType;

    /* Get the IP Address */
    strncpy(IPAddress, profileDetails->IPAddress, strlen(profileDetails->IPAddress) + 1);
    resultCode = GetIPFromUser( "IP", IPAddress, &profileInfo.IPAddress );
    if( resultCode != SUCCESS )
    {
        TRACE_MSG( LOG_ERR, fp, "Invalid IPAddress : %u\n", resultCode);
        return -1;
    }
    profileToCreate.curProfile.SlqsProfile3GPP.pIPv4AddrPref = &profileInfo.IPAddress;
    resultCode = 0;

    /* Get the Primary DNS Address */
    strncpy(IPAddress, profileDetails->primaryDNS, strlen(profileDetails->primaryDNS) + 1);
    resultCode = GetIPFromUser( "PrimaryDNS Address", IPAddress, &profileInfo.primaryDNS );
    if( resultCode != SUCCESS )
    {
        TRACE_MSG( LOG_ERR, fp, "Invalid PrimaryDNS : %u\n", resultCode);
        return -1;
    }

    profileToCreate.curProfile.SlqsProfile3GPP.pPriDNSIPv4AddPref = &profileInfo.primaryDNS;
    resultCode = 0;

    /* Get the Secondary DNS Address */
    strncpy(IPAddress, profileDetails->secondaryDNS, strlen(profileDetails->secondaryDNS) + 1);
    resultCode = GetIPFromUser( "SecondaryDNS Address", IPAddress, &profileInfo.secondaryDNS );
    if( resultCode != SUCCESS )
    {
        TRACE_MSG( LOG_ERR, fp, "Invalid SecondaryDNS : %u\n", resultCode);
        return -1;
    }
    profileToCreate.curProfile.SlqsProfile3GPP.pSecDNSIPv4AddPref = &profileInfo.secondaryDNS;
    resultCode = 0;

    /* Get Authentication From the user */
    if(profileDetails->authenticationValue > 3)
    {
        TRACE_MSG(LOG_ERR, fp, "Invalid Authentication value\n");
        TRACE_MSG(LOG_INFO, fp, "Valid Authentication value 0 - None, 1 - PAP, 2 - CHAP, 3 - PAP/CHAP\n");
        return -1;
    }
    authValue = profileDetails->authenticationValue;
    profileToCreate.curProfile.SlqsProfile3GPP.pAuthenticationPref = &authValue;

    /* Get Profile Name from the user, Max size is 14 characters */
    memset(profileInfo.profileName, 0, MAX_PROFILE_NAME_SIZE);
    strncpy(profileInfo.profileName, profileDetails->profileName, MAX_PROFILE_NAME_SIZE);
    if( profileInfo.profileName == NULL )
    {
        TRACE_MSG(LOG_ERR, fp, "Invalid Profile Name - should not be null\n");
        return -1;
    }
    profileToCreate.curProfile.SlqsProfile3GPP.pProfilename = profileInfo.profileName;

    /* Get APN Name from the user */
    memset(profileInfo.APNName, 0, MAX_APN_SIZE);
    strncpy(profileInfo.APNName, profileDetails->APNName, MAX_APN_SIZE);
    if( profileInfo.APNName == NULL )
    {
        TRACE_MSG(LOG_ERR, fp, "Invalid APN Name - should not be null\n");
        return -1;
    }
    profileToCreate.curProfile.SlqsProfile3GPP.pAPNName = profileInfo.APNName;

    /* Get User Name from the user */
    memset(profileInfo.userName, 0, MAX_USER_NAME_SIZE);
    strncpy(profileInfo.userName, profileDetails->userName, MAX_USER_NAME_SIZE);
    if( profileInfo.userName == NULL )
    {
        TRACE_MSG(LOG_ERR, fp, "Invalid UserName Name - should not be null\n");
        return -1;
    }
    profileToCreate.curProfile.SlqsProfile3GPP.pUsername = profileInfo.userName;

    /* Get Password from the user */
    memset(profileInfo.password, 0, MAX_FIELD_SIZE);
    strncpy(profileInfo.password, profileDetails->password, MAX_FIELD_SIZE);
    if( profileInfo.password == NULL )
    {
        TRACE_MSG(LOG_ERR, fp, "Invalid password value - should not be null\n");
        return -1;
    }
    profileToCreate.curProfile.SlqsProfile3GPP.pPassword = profileInfo.password;

    /* Set the profile with the required fields */
    resultCode = SLQSCreateProfile( &profileToCreate,
                                    &profileCreatedresult );
    if( SUCCESS != resultCode )
    {
        TRACE_MSG( LOG_ERR, fp, "Profile Creation Failed\n"
                 "Failure cause  - %lu\nFailure Reason - %d\n",
                 resultCode, *(profileCreatedresult.pExtErrorCode) );
        return -1;
    }
    TRACE_MSG( LOG_INFO, fp, "Profile created successfully for Profile ID:"
                      " %d\n", *(profileCreatedresult.pProfileIndex) );
    return SUCCESS;
}

/*
 * Name:     DisplayAllProfiles
 *
 * Purpose:  Display all the profiles stored on the device.
 *
 * Params:   None
 *
 * Return:   None
 *
 * Notes:    None
 */
static void DisplayAllProfiles()
{
    ULONG resultCode = 0;
    ULONG profileType = PROFILE_TYPE_UMTS;
    BYTE  profileId;
    ULONG PDPType;
    CHAR  bufIPAddress[MAX_FIELD_SIZE];
    ULONG IPAddress;
    CHAR  bufPrimaryDNS[MAX_FIELD_SIZE];
    ULONG primaryDNS;
    CHAR  bufSecondaryDNS[MAX_FIELD_SIZE];
    ULONG secondaryDNS;
    ULONG authentication;
    CHAR  profileName[MAX_PROFILE_NAME_SIZE];
    CHAR  APNName[MAX_APN_SIZE];
    CHAR  Username[MAX_USER_NAME_SIZE];
    WORD  extendedErrorCode = 0;
    indexInfo.totalProfilesOnDevice = 0;

    /* Display the header */
    TRACE_MSG( LOG_INFO, fp, "%s %s %s %s %s %s %s %s %s", "ID", "PDPType", "IPAddress",
                     "PrimaryDNS", "SecondaryDNS", "Auth", "ProfileName",
                      "APNName", "UserName" );

    /* Retrieve the information for all the profiles loaded on the device */
    for( profileId = MIN_PROFILES; profileId <= MAX_PROFILES; profileId++ )
    {
        /* Initialize the buffers */
        memset( profileName, 0, MAX_PROFILE_NAME_SIZE );
        memset( APNName, 0, MAX_APN_SIZE );
        memset( Username, 0, MAX_USER_NAME_SIZE );
        IPAddress      = 0;
        primaryDNS     = 0;
        secondaryDNS   = 0;
        authentication = 0;

        resultCode = SLQSGetProfile( profileType,
                                     profileId,
                                     &PDPType,
                                     &IPAddress,
                                     &primaryDNS,
                                     &secondaryDNS,
                                     &authentication,
                                     MAX_PROFILE_NAME_SIZE,
                                     profileName,
                                     MAX_APN_SIZE,
                                     APNName,
                                     MAX_USER_NAME_SIZE,
                                     Username,
                                     &extendedErrorCode );

        /* If the profile does not exist on the device or we failed to retrieve
         * the information about the profile.
         */
        if( SUCCESS != resultCode )
        {
              return;
        }

        /* Store the profile indexes for successfully retrieved profiles */
        indexInfo.profileIndex[indexInfo.totalProfilesOnDevice] = profileId;
        indexInfo.totalProfilesOnDevice++;

        /* Reset the buffers */
        memset( bufIPAddress, 0, MAX_FIELD_SIZE );
        memset( bufPrimaryDNS, 0, MAX_FIELD_SIZE );
        memset( bufSecondaryDNS, 0, MAX_FIELD_SIZE );

        /* Convert ULONG to Dot notation for display */
        IPUlongToDot( IPAddress, bufIPAddress );
        IPUlongToDot( primaryDNS, bufPrimaryDNS );
        IPUlongToDot( secondaryDNS, bufSecondaryDNS );

        /* Display the retrieved profile information */
        TRACE_MSG( LOG_INFO, fp, "%u %u %s %s %s %u %s %s %s", profileId, PDPType, bufIPAddress,
                         bufPrimaryDNS, bufSecondaryDNS, authentication,
                         profileName, APNName, Username );
    }
}

/*
 * Name:     DisplayAllProfile
 *
 * Purpose:  Call DisplayAllProfiles to display all the profiles stored on the
 *           device.
 *
 * Params:   None
 *
 * Return:   None
 *
 * Notes:    None
 */
void DisplayAllProfile()
{
    DisplayAllProfiles();
    if( 0 == indexInfo.totalProfilesOnDevice )
    {
        TRACE_MSG( LOG_ERR, fp, "No Profile exist on the device"\
                         "or check device connectivity\n\n" );
    }
}

/*************************************************************************
 *                         Call Back Functions
 ************************************************************************/
/*
 * Name:     DevStateChgCbk
 *
 * Purpose:  Device State change callback
 *
 * Params:   devstatus - the current state of the device
 *
 * Return:   None
 *
 * Notes:    None
 */
void DevStateChgCbk( eDevState devstatus )
{
    BYTE count;
    TRACE_MSG(LOG_INFO, fp, "Device state changes\n");
    /* If device is ready to communicate */
    if( devstatus ==  DEVICE_STATE_READY )
    {
        TRACE_MSG(LOG_INFO, fp, "DEVICE CONNECTED\n");
        devready = 1;
    }
    else if( devstatus ==  DEVICE_STATE_DISCONNECTED )
    {
        /* Device is disconnected */
        for( count = 0; count <= MAX_INST_ID; count++ )
        {
            slte[count].v4sessionId = 0;
            sumts[count].v6sessionId = 0;
        }

        /* Reset Global varibales related to session if device resets */
        sessionNum = 0;
        sessionNumLte = 0;
        TRACE_MSG(LOG_INFO, fp, "DEVICE CONNECTED\n");
    }
    else
    {
        TRACE_MSG(LOG_INFO, fp, "UNKNOWN\n");
    }
}

/*
 * Name:     SignalStrengthCallback
 *
 * Purpose:  Signal Strength Callback function
 *
 * Params:   signalStrength - Received signal strength (in dBm)
 *           radioInterface - Radio interface technology of the signal being
 *                            measured
 *
 * Return:   None
 *
 * Notes:    None
 */
void SignalStrengthCallback(
   INT8  signalStrength,
   ULONG radioInterface )
{
    CHAR signalStrengthBuf[10];
    UNUSEDPARAM ( radioInterface );

    /* Update the Signal Strength field of the user window */
    TRACE_MSG(LOG_INFO, fp, "Signal strength changes : %d", signalStrength );
}

/*
 * Name:     DisplayRadioInterface
 *
 * Purpose:  Display the radio interface field in the log file
 *
 * Params:   radioInterface - Radio interface technology of the signal being
 *                            measured
 * Return:   None
 *
 * Notes:    None
 */
void DisplayRadioInterface( ULONG radioInterface, char *interfaceName )
{
    /* Update the Radio Interface in logs */
    if( eNO_SERVICE == radioInterface )
    {
        strcpy(interfaceName, "NO SERVICE");
    }
    else if( eCDMA_1xRTT == radioInterface )
    {
        strcpy(interfaceName, "CDMA 1xRTT");
    }
    else if( eCDMA_1xEVDO == radioInterface )
    {
        strcpy(interfaceName, "CDMA 1xEV-DO");
    }
    else if( eAMPS == radioInterface )
    {
        strcpy(interfaceName, "AMPS");
    }
    else if( eGSM == radioInterface )
    {
        strcpy(interfaceName, "GSM");
    }
    else if( eUMTS == radioInterface )
    {
        strcpy(interfaceName, "UMTS");
    }
    else if( eWLAN == radioInterface)
    {
        strcpy(interfaceName, "WLAN");
    }
    else if( eGPS == radioInterface)
    {
        strcpy(interfaceName, "GPS");
    }
    else if( eLTE == radioInterface)
    {
        strcpy(interfaceName, "LTE");
    }
    else
    {
        strcpy(interfaceName, "UNKNOWN");
    }
}

/*
 * Name:     RFInfoCallback
 *
 * Purpose:  RF Information Callback function
 *
 * Params:   radioInterface  - Radio interface technology of the signal being
 *                             measured
 *           activeBandClass - Active band class
 *           activeChannel   - Active channel
 *                             - 0 - Channel is not relevant to the reported
 *                                   technology
 *
 * Return:   None
 *
 * Notes:    None
 */
void RFInfoCallback(
   ULONG radioInterface,
   ULONG activeBandClass,
   ULONG activeChannel )
{
    ULONG low_channel, high_channel, result = 0;
    FILE *inputFile = NULL;
    char wifi_buffer[MAX_LENGTH], wifi_channel[MAX_LENGTH], command[MAX_LENGTH], responseBuffer[MAX_LENGTH];
    struct stat fileAttribute;

    UNUSEDPARAM ( activeChannel );

    TRACE_MSG(LOG_INFO, fp, "RF info changes\n");

    /* Update the Radio Interface field in logs */
    memset(&responseBuffer, 0, MAX_LENGTH);
    DisplayRadioInterface( radioInterface, &responseBuffer);

    TRACE_MSG(LOG_INFO, fp, "RF Interface : %s\n", responseBuffer);
    strcpy(sessionOutput.radio_interface, responseBuffer );

    /* Update the Active Band field in logs */
    memset(&responseBuffer, 0, MAX_LENGTH);
    TRACE_MSG(LOG_INFO, fp, "Band class : %lu\n", activeBandClass);
    sprintf(responseBuffer, "%lu", activeBandClass);
    strcpy(sessionOutput.band_class, responseBuffer );

    /* Update the Active Channel field in logs */
    memset(&responseBuffer, 0, MAX_LENGTH);
    TRACE_MSG(LOG_INFO, fp, "Active Channel : %lu\n", activeChannel);
    sprintf(responseBuffer, "%lu", activeChannel);
    strcpy(sessionOutput.active_channel, responseBuffer );

    inputFile = fopen ("/usr/lib/lte-cm/lte_channel_table.txt","r");
    if(inputFile == NULL)
    {
        TRACE_MSG(LOG_ERR, fp, "lte_channel_table.txt : %s\n", strerror(errno));
        return;
    }

    while(fgets(wifi_buffer, MAX_LENGTH, inputFile) != NULL)
    {
        if(*wifi_buffer == '#') /* Skip comment lines */
        {
           continue;
        }

        memset(wifi_channel, 0, MAX_LENGTH);
        if(sscanf(wifi_buffer,"%lu %lu %s", &low_channel, &high_channel, wifi_channel) != 3)
        {
           TRACE_MSG(LOG_ERR, fp, "lte_channel_table.txt: %s invalid table entry\n", wifi_buffer);
           return;
        }

        strtok(wifi_channel, "\n");
        if(activeChannel >= low_channel && activeChannel <= high_channel)
        {
            if(stat("/usr/bin/channel_avoidance.sh", &fileAttribute) < 0)
            {
                TRACE_MSG(LOG_ERR, fp, "channel_avoidance.sh : %s\n", strerror(errno));
                return;
            }

            snprintf(command, MAX_LENGTH, "/usr/bin/channel_avoidance.sh %s ", wifi_channel);
            TRACE_MSG(LOG_INFO, fp, "calling : %s", command);
            if((result = system(command) != 0))
            {
                TRACE_MSG(LOG_ERR, fp, "channel_avoidance.sh script call failed : %lu\n", result);
            }
        }
    }
    fclose(inputFile);
}


/*
 * Name:     SessionStateCallback
 *
 * Purpose:  Session State Callback function
 *
 * Params:   state            - Current Link Status
 *                              - 1 Disconnected
 *                              - 2 Connected
 *                              - 3 Suspended (Unsupported)
 *                              - 4 Authenticating
 *           sessionEndReason - Call End Reason
 *
 * Return:   None
 *
 * Notes:    None
 */
void SessionStateCallback(
    slqsSessionStateInfo *pSessionInfo )
{
    UNUSEDPARAM ( pSessionInfo->sessionEndReason );


    TRACE_MSG(LOG_INFO, fp, "Session State changes\n");
    /* Update the session state field in logs */
    if( eSTATE_DISCONNECTED == pSessionInfo->state)
    {
        TRACE_MSG(LOG_INFO, fp, "Session State : %s\n", "DISCONNECTED");
    }
    else if( eSTATE_CONNECTED == pSessionInfo->state)
    {
        TRACE_MSG(LOG_INFO, fp, "Session State : %s\n", "CONNECTED");
    }
    else if( eSTATE_SUSPENDED == pSessionInfo->state)
    {
        TRACE_MSG(LOG_INFO, fp, "Session State : %s\n", "SUSPENDED");
    }
    else if( eSTATE_AUTHENTICATING == pSessionInfo->state)
    {
        TRACE_MSG(LOG_INFO, fp, "Session State : %s\n", "AUTHENTICATING");
    }
    else
    {
        TRACE_MSG(LOG_INFO, fp, "Session State : %s\n", "UNKNOWN");
    }
}

/*
 * Name:     RoamingIndicatorCallbck
 *
 * Purpose:  Roaming Indicator Callback function
 *
 * Params:   roaming - Roaming Indication
 *                     - 0  - Roaming
 *                     - 1  - Home
 *                     - 2  - Roaming partner
 *                     - >2 - Operator defined values
 *
 * Return:   None
 *
 * Notes:    None
 */
void RoamingIndicatorCallbck( ULONG roaming )
{
    /* Update the roaming status */
    TRACE_MSG(LOG_INFO, fp, "Roaming State changes\n");
    if( eROAMING == roaming )
    {
        TRACE_MSG(LOG_INFO, fp, "Roaming State : %s\n", "ON ROAMING");
    }
    else if( eHOME == roaming )
    {
        TRACE_MSG(LOG_INFO, fp, "Roaming State : %s\n", "IN HOME");
    }
    else if( eROAMING_PARTNER == roaming )
    {
        TRACE_MSG(LOG_INFO, fp, "Roaming State : %s\n", "ROAMING PARTNER");
    }
    else
    {
        TRACE_MSG(LOG_INFO, fp, "Roaming State : %s\n", "UNKNOWN");
    }
}

/*
 * Name:     UnSubscribeCallbacks
 *
 * Purpose:  De register all the callbacks registered at the beginning.
 *
 * Params:   None
 *
 * Return:   None
 *
 * Notes:    None
 */
static void UnSubscribeCallbacks()
{
    ULONG                            resultCode = 0;

    resultCode = SLQSSetSessionStateCallback( NULL );
    if( SUCCESS != resultCode )
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to subscribe for SLQSSetSessionStateCallback: %lu\n",
                    resultCode );
    }

    resultCode = SetRFInfoCallback( NULL );
    if( SUCCESS != resultCode )
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to subscribe for SetRFInfoCallback: %lu\n",
                    resultCode );
    }

    resultCode = SetDeviceStateChangeCbk( NULL );
    if( SUCCESS != resultCode )
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to subscribe for SetDeviceStateChangeCbk: %lu\n",
                    resultCode );
    }

    resultCode = SetRoamingIndicatorCallback( NULL );
    if( SUCCESS != resultCode )
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to subscribe for SetRoamingIndicatorCallback: %lu\n",
                    resultCode );
    }

}

/*
 * Name:     SubscribeCallbacks
 *
 * Purpose:  Subscribed to all the required callbacks from the device.
 *
 * Params:   None
 *
 * Return:   None
 *
 * Notes:    None
 */
void SubscribeCallbacks()
{
    ULONG                            resultCode = 0;

    WORD              cdmaRssiThreshList[2] = { -1020,-400 };/* -102dB, -40dB */
    BYTE              cdmaRssiThreshListlen = 0x02;
    CDMARSSIThresh    cdmaRssiThresh;

    WORD              cdmaEcioThreshList[2] = { -400, -310 }; /* -20dB, -15.5dB */
    BYTE              cdmaEcioThreshListLen = 0x02;
    CDMAECIOThresh    cdmaEcioThresh;

    WORD              hdrRssiThreshList[2] = { -500, -150 }; /* -50dB, -15dB */
    BYTE              hdrRssiThresListLen = 2;
    HDRRSSIThresh     hdrRssiThresh;

    WORD              hdrEcioThreshList[2] = { -400, -310 }; /* -20dB, -15.5dB */
    BYTE              hdrEcioThresListLen = 2;
    HDRECIOThresh     hdrEcioThresh;

    WORD              hdrSinrThreshList[2] = { 0x01, 0x03 }; /* -6dB, -3dB */
    BYTE              hdrSinrThresListLen = 2;
    HDRSINRThreshold  hdrSinrThresh;

    WORD              hdrIoThreshList[2] = { -1110, -730 }; /* -110dB, -73dB */
    BYTE              hdrIoThresListLen = 2;
    HDRIOThresh       hdrIoThresh;

    WORD              gsmRssiThreshList[2] = { -950, -800 }; /* -95dB, -80dB */
    BYTE              gsmRssiThresListLen = 2;
    GSMRSSIThresh     gsmRssiThresh;

    WORD              wcdmaRssiThreshList[2] = { -1000, -200 }; /* -100dB, -20dB */
    BYTE              wcdmaRssiThresListLen = 2;
    WCDMARSSIThresh   wcdmaRssiThresh;

    WORD              wcdmaEcioThreshList[2] = { -400, -310 }; /* -20dB, -15.5dB */
    BYTE              wcdmaEcioThresListLen = 2;
    WCDMAECIOThresh   wcdmaEcioThresh;

    WORD              lteRssiThreshList[2] = { -1000, -400 }; /* -100dB, -40dB */
    BYTE              lteRssiThresListLen = 2;
    LTERSSIThresh     lteRssiThresh;

    WORD              lteSnrThreshList[2] = { -198, -230 }; /* -19.8dB, 23dB */
    BYTE              lteSnrThresListLen = 2;
    LTESNRThreshold   lteSnrThresh;

    WORD              lteRsrqThreshList[2] = { -110, -60 }; /* -11dB, -6dB */
    BYTE              lteRsrqThresListLen = 2;
    LTERSRQThresh     lteRsrqThresh;

    WORD              lteRsrpThreshList[2] = { -1250, -640 }; /* -125dB, -64dB */
    BYTE              lteRsrpThresListLen = 2;
    LTERSRPThresh     lteRsrpThresh;

    WORD              tdscdmaRscpThreshList[2] = { -950, -800 }; /* -95dB, -80dB */
    BYTE              tdscdmaRscpThresListLen = 2;
    TDSCDMARSCPThresh tdscdmaRscpThresh;

    float             tdscdmaRssiThreshList[2] = { -950, -800 }; /* -95dB, -80dB */
    BYTE              tdscdmaRssiThresListLen = 2;
    TDSCDMARSSIThresh tdscdmaRssiThresh;

    float             tdscdmaEcioThreshList[2] = { -400, -310 }; /* -20dB, -15.5dB */
    BYTE              tdscdmaEcioThresListLen = 2;
    TDSCDMAECIOThresh tdscdmaEcioThresh;

    float             tdscdmaSinrThreshList[2] = { 0x01, 0x03 };
    BYTE              tdscdmaSinrThresListLen = 2;
    TDSCDMASINRThresh tdscdmaSinrThresh;

    BYTE                rptRate = 2;
    BYTE                avgPeriod = 2;
    LTESigRptConfig     lteSigRptCfg;

    setSignalStrengthInfo      req;

    /* Initialize the structure */
    memset( (char*)&req, 0, sizeof(req) );

    /* Assign request parameters */
    cdmaRssiThresh.CDMARSSIThreshListLen = cdmaRssiThreshListlen;
    cdmaRssiThresh.pCDMARSSIThreshList   = cdmaRssiThreshList;
    req.pCDMARSSIThresh                  = &cdmaRssiThresh;

    cdmaEcioThresh.CDMAECIOThreshListLen = cdmaEcioThreshListLen;
    cdmaEcioThresh.pCDMAECIOThreshList   = cdmaEcioThreshList;
    req.pCDMAECIOThresh                  = &cdmaEcioThresh;

    hdrRssiThresh.HDRRSSIThreshListLen   = hdrRssiThresListLen;
    hdrRssiThresh.pHDRRSSIThreshList     = hdrRssiThreshList;
    req.pHDRRSSIThresh                   = &hdrRssiThresh;

    hdrEcioThresh.HDRECIOThreshListLen   = hdrEcioThresListLen;
    hdrEcioThresh.pHDRECIOThreshList     = hdrEcioThreshList;
    req.pHDRECIOThresh                   = &hdrEcioThresh;

    hdrSinrThresh.HDRSINRThreshListLen   = hdrSinrThresListLen;
    hdrSinrThresh.pHDRSINRThreshList     = hdrSinrThreshList;
    req.pHDRSINRThresh                   = &hdrSinrThresh;

    hdrIoThresh.HDRIOThreshListLen       = hdrIoThresListLen;
    hdrIoThresh.pHDRIOThreshList         = hdrIoThreshList;
    req.pHDRIOThresh                     = &hdrIoThresh;

    gsmRssiThresh.GSMRSSIThreshListLen   = gsmRssiThresListLen;
    gsmRssiThresh.pGSMRSSIThreshList     = gsmRssiThreshList;
    req.pGSMRSSIThresh                   = &gsmRssiThresh;

    wcdmaRssiThresh.WCDMARSSIThreshListLen   = wcdmaRssiThresListLen;
    wcdmaRssiThresh.pWCDMARSSIThreshList     = wcdmaRssiThreshList;
    req.pWCDMARSSIThresh                     = &wcdmaRssiThresh;

    wcdmaEcioThresh.WCDMAECIOThreshListLen   = wcdmaEcioThresListLen;
    wcdmaEcioThresh.pWCDMAECIOThreshList     = wcdmaEcioThreshList;
    req.pWCDMAECIOThresh                     = &wcdmaEcioThresh;

    lteRssiThresh.LTERSSIThreshListLen   = lteRssiThresListLen;
    lteRssiThresh.pLTERSSIThreshList     = lteRssiThreshList;
    req.pLTERSSIThresh                   = &lteRssiThresh;

    lteSnrThresh.LTESNRThreshListLen   = lteSnrThresListLen;
    lteSnrThresh.pLTESNRThreshList     = lteSnrThreshList;
    req.pLTESNRThresh                  = &lteSnrThresh;

    lteRsrqThresh.LTERSRQThreshListLen   = lteRsrqThresListLen;
    lteRsrqThresh.pLTERSRQThreshList     = lteRsrqThreshList;
    req.pLTERSRQThresh                  = &lteRsrqThresh;

    lteRsrpThresh.LTERSRPThreshListLen = lteRsrpThresListLen;
    lteRsrpThresh.pLTERSRPThreshList   = lteRsrpThreshList;
    req.pLTERSRPThresh                 = &lteRsrpThresh;

    tdscdmaRscpThresh.TDSCDMARSCPThreshListLen = tdscdmaRscpThresListLen;
    tdscdmaRscpThresh.pTDSCDMARSCPThreshList   = tdscdmaRscpThreshList;
    req.pTDSCDMARSCPThresh                     = &tdscdmaRscpThresh;

    tdscdmaRssiThresh.TDSCDMARSSIThreshListLen = tdscdmaRssiThresListLen;
    tdscdmaRssiThresh.pTDSCDMARSSIThreshList   = (ULONG*)tdscdmaRssiThreshList;
    req.pTDSCDMARSSIThresh                     = &tdscdmaRssiThresh;

    tdscdmaEcioThresh.TDSCDMAECIOThreshListLen = tdscdmaEcioThresListLen;
    tdscdmaEcioThresh.pTDSCDMAECIOThreshList   = (ULONG*)tdscdmaEcioThreshList;
    req.pTDSCDMAECIOThresh                     = &tdscdmaEcioThresh;

    tdscdmaSinrThresh.TDSCDMASINRThreshListLen = tdscdmaSinrThresListLen;
    tdscdmaSinrThresh.pTDSCDMASINRThreshList   = (ULONG*)tdscdmaSinrThreshList;
    req.pTDSCDMASINRThresh                     = &tdscdmaSinrThresh;

    lteSigRptCfg.rptRate   = rptRate;
    lteSigRptCfg.avgPeriod = avgPeriod;
    req.pLTESigRptConfig   = &lteSigRptCfg;

    BYTE                             instance;

    resultCode = SLQSSetSessionStateCallback( &SessionStateCallback );
    if( SUCCESS != resultCode )
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to subscribe for SessionStateCallback : %lu\n",
                    resultCode );
    }

    resultCode = SetRFInfoCallback( RFInfoCallback );
    if( SUCCESS != resultCode )
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to subscribe for  SetRFInfoCallback: %lu\n",
                    resultCode );
    }

    resultCode = SetDeviceStateChangeCbk( DevStateChgCbk );
    if( SUCCESS != resultCode )
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to subscribe for SetDeviceStateChangeCallback : %lu\n",
                    resultCode );
    }

    resultCode = SetRoamingIndicatorCallback( RoamingIndicatorCallbck );
    if( SUCCESS != resultCode )
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to subscribe for SetRoamingIndicatorCallback : %lu\n",
                    resultCode );
    }
}

/*
 * Name:     IsConnectedDeviceGOBI
 *
 * Purpose:  Checks whether the connected device is a GOBI device or not.
 *
 * Params:   None
 *
 * Return:   TRUE   - If the connected device is a GOBI device.
 *           FALSE  - If the connected device is not a GOBI device
 *
 * Notes:    None
 */
BYTE IsConnectedDeviceGOBI()
{
    BYTE  stringSize = MAX_FIELD_SIZE;
    CHAR  modelId[MAX_FIELD_SIZE];
    CHAR  *pStr = NULL;

    /* Get the model Id of the device */
    GetModelID( stringSize, modelId );

    /* Search for a MC77 string in the received model id */
    pStr = strstr( modelId, "MC83" );

    /* If the device is a GOBI device */
    if ( pStr != NULL )
    {
        return TRUE;
    }
    else
    {
        return FALSE;
    }
}

static ULONG getRegState()
{
    ULONG nRet;
    SrvStatusInfo      cdmassi;
    SrvStatusInfo      hdrssi;
    GSMSrvStatusInfo   gsmssi;
    GSMSrvStatusInfo   wcdmassi;
    GSMSrvStatusInfo   ltessi;
    nasGetSysInfoResp resp;
    resp.pCDMASrvStatusInfo  = &cdmassi;
    resp.pHDRSrvStatusInfo   = &hdrssi;
    resp.pGSMSrvStatusInfo   = &gsmssi;
    resp.pWCDMASrvStatusInfo = &wcdmassi;
    resp.pLTESrvStatusInfo   = &ltessi;
    resp.pCDMASysInfo        = NULL;
    resp.pHDRSysInfo         = NULL;
    resp.pGSMSysInfo         = NULL;
    resp.pWCDMASysInfo       = NULL;
    resp.pLTESysInfo         = NULL;
    resp.pAddCDMASysInfo     = NULL;
    resp.pAddHDRSysInfo      = NULL;
    resp.pAddGSMSysInfo      = NULL;
    resp.pAddWCDMASysInfo    = NULL;
    resp.pAddLTESysInfo      = NULL;
    resp.pGSMCallBarringSysInfo = NULL;
    resp.pWCDMACallBarringSysInfo  = NULL;
    resp.pLTEVoiceSupportSysInfo   = NULL;
    resp.pGSMCipherDomainSysInfo   = NULL;
    resp.pWCDMACipherDomainSysInfo = NULL;
    ULONG RegistrationState = 0xFF;

    nRet = SLQSNasGetSysInfo( &resp );

    if( eQCWWAN_ERR_NONE == nRet )
    {
        if ( resp.pCDMASrvStatusInfo->srvStatus == 2 )
        {
            RegistrationState = (ULONG)resp.pCDMASrvStatusInfo->srvStatus;
        }
        else if ( resp.pHDRSrvStatusInfo->srvStatus == 2 )
        {
            RegistrationState = (ULONG) resp.pHDRSrvStatusInfo->srvStatus;
        }
        else if ( resp.pGSMSrvStatusInfo->srvStatus == 2 )
        {
            RegistrationState = (ULONG)resp.pGSMSrvStatusInfo->srvStatus;
        }
        else if ( resp.pWCDMASrvStatusInfo->srvStatus == 2 )
        {
            RegistrationState = (ULONG)resp.pWCDMASrvStatusInfo->srvStatus;
        }
        else if ( resp.pLTESrvStatusInfo->srvStatus ==2 )
        {
            RegistrationState =(ULONG)resp.pLTESrvStatusInfo->srvStatus;
        }
        return RegistrationState;
    }
    else
    {
        return ~0;
    }
}

/*
 * Name:     StartLteCdmaDataSession
 *
 * Purpose:  Starts a LTE or CDMA Data Session
 *
 * Params:   isCdma - TRUE for CDMA connection
 *
 * Return:   None
 *
 * Notes:    None
 */

ULONG StartLteCdmaDataSession(BOOL isCdma, ULONG profileId3gpp, BYTE IPFamilyPreference)
{
    ULONG                       technology = (isCdma) ? TECHNOLOGY_3GPP2: TECHNOLOGY_3GPP;
    ULONG                       resultCode = 0;
    BYTE                        profileIdMatch = FALSE;
    BYTE                        idx = 0;
    ULONG                       regState;
    CHAR                        responseBuffer[RESP_BUFFER_LEN];

    /* If connected device is GOBI, return after displaying an error message
     * as LTE data call is not supported on GOBI devices.
     */
    if( TRUE == IsConnectedDeviceGOBI() )
    {
        TRACE_MSG(LOG_ERR, fp, "LTE/CDMA Data call not supported on this device!!!\n" );
        return -1;
    }

    /* check registration state */
    regState = getRegState();
    if ( 2 != regState )
    {
        TRACE_MSG(LOG_ERR, fp, "Modem not registered to network, reg state %ld\n", regState);
        return -1;
    }

    /* Get the Model ID */
    resultCode = GetModelID( RESP_BUFFER_LEN, responseBuffer );
    if( SUCCESS != resultCode )
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to get Model ID\n" );
        TRACE_MSG(LOG_ERR, fp, "Failure Code : %lu\n", resultCode );
        return -1;
    }

    if ( (0 == strcmp("SL9090", responseBuffer) ||\
          0 == strcmp("MC9090", responseBuffer)) && (1 == isCdma))
    {
        /* Fill the information for required data session, for SL9090, it only supports mono PDN,
           hence, do not consider mutiple PDN in this case */
        slte[0].action = START_DATA_SEESION;
        slte[0].instanceId = 0;
        slte[0].pTechnology = &technology;
        slte[0].ipfamily = IPv4_FAMILY_PREFERENCE;

        resultCode = SLQSStartStopDataSession(&slte[0]);
        if (SUCCESS != resultCode )
        {
            TRACE_MSG(LOG_ERR, fp, "Failed to start CDMA Data Session\n" );
            TRACE_MSG(LOG_ERR, fp, "Failure Code : %lu\n", resultCode);
            TRACE_MSG(LOG_ERR, fp, "WDS Call End Reason : %lu\n", slte[0].failureReason );
            TRACE_MSG(LOG_ERR, fp, "Verbose Failure Reason Type: %lu\n", slte[0].verbFailReasonType );
            return -1;
        }
    }
    else
    {

        /* Fill the information for required data session */
        slte[sessionNumLte].action = START_DATA_SEESION;
        slte[sessionNumLte].instanceId = sessionNumLte;/* InstanceId  will be same as sessionNumLte */
        slte[sessionNumLte].pTechnology = &technology;
        if (isCdma)
        {
            slte[sessionNumLte].pProfileId3GPP = NULL;
            profileId3gpp += CDMA_PROFILE_OFFSET;
            slte[sessionNumLte].pProfileId3GPP2 = &profileId3gpp;
        }
        else
        {
            slte[sessionNumLte].pProfileId3GPP = &profileId3gpp;
            slte[sessionNumLte].pProfileId3GPP2 = NULL;
        }
        slte[sessionNumLte].ipfamily = IPFamilyPreference;
        resultCode = SLQSStartStopDataSession(&slte[sessionNumLte]);

        /* Several reasons are possible to have a non-zero result code
         *         Result Code                    Reason
         *
         * eQCWWAN_ERR_SWICM_V4UP_V6DWN  - IPv4v6 family preference was set. IPv4
         *                                 call succeeded, IPv6 call failed.
         * eQCWWAN_ERR_SWICM_V4DWN_V6UP  - IPv4v6 family preference was set. IPv4
         *                                 call failed, IPv6 call succeeded.
         * eQCWWAN_ERR_SWICM_V4DWN_V6DWN - IPv4v6 family preference was set. IPv4
         *                                 call succeeded, IPv6 call failed.
         * eQCWWAN_ERR_SWICM_V4UP_V6UP   - IPv4v6 family preference was set. Both
         *                                 IPv4 and IPv6 call succeeded.
         * eQCWWAN_ERR_xxx               - IPv4/IPv6 family preference was set and
         *                                 data call failed.
         */

        if( SUCCESS != resultCode )
        {
            if( IPv4v6_FAMILY_PREFERENCE == IPFamilyPreference )
            {
                TRACE_MSG(LOG_INFO, fp,
                         "Start IPv4v6 LTE/CDMA data session( Instance: %x ) status:\n",
                         sessionNumLte );
                switch( resultCode)
                {
                    case eQCWWAN_ERR_SWICM_V4UP_V6DWN:
                        TRACE_MSG(LOG_INFO, fp, "1. IPv4 session - connected\n" );
                        TRACE_MSG(LOG_INFO, fp, "2. IPv6 session - disconnected\n" );
                        UpdateUserDisplay( eCALL_STATUS, "CONNECTED" );
                        break;
                    case eQCWWAN_ERR_SWICM_V4DWN_V6UP:
                        TRACE_MSG(LOG_INFO, fp, "1. IPv4 session - disconnected\n" );
                        TRACE_MSG(LOG_INFO, fp, "2. IPv6 session - connected\n" );
                        UpdateUserDisplay( eCALL_STATUS, "CONNECTED" );
                        break;
                    case eQCWWAN_ERR_SWICM_V4DWN_V6DWN:
                        TRACE_MSG(LOG_INFO, fp, "1. IPv4 session - disconnected\n" );
                        TRACE_MSG(LOG_INFO, fp, "2. IPv6 session - disconnected\n" );
                        UpdateUserDisplay( eCALL_STATUS, "DISCONNECTED" );
                        return -1;
                        break;
                    case eQCWWAN_ERR_SWICM_V4UP_V6UP:
                        TRACE_MSG(LOG_INFO, fp, "1. IPv4 session - connected: %lu \n", slte[sessionNumLte].v4sessionId);
                        TRACE_MSG(LOG_INFO, fp, "2. IPv6 session - connected: %lu \n", slte[sessionNumLte].v6sessionId);
                        UpdateUserDisplay( eCALL_STATUS, "CONNECTED" );
                        break;
                    default:
                        break;
                }
            }
            else
            {
                TRACE_MSG(LOG_ERR, fp, "Failed to start LTE/CDMA Data Session" );
                TRACE_MSG(LOG_ERR, fp, "Failure Code : %lu(0x%04lx)\n", resultCode
                        , resultCode );
                TRACE_MSG(LOG_ERR, fp, "WDS Call End Reason : %lu(0x%04lx)\n",
                        slte[sessionNumLte].failureReason,
                        slte[sessionNumLte].failureReason );
                TRACE_MSG(LOG_ERR, fp,
                         "Verbose Failure Reason Type: %lu(0x%04lx)\n",
                         slte[sessionNumLte].verbFailReasonType,
                         slte[sessionNumLte].verbFailReasonType );
                TRACE_MSG(LOG_ERR, fp,
                         "Verbose Failure Reason : %lu(0x%04lx)\n",
                         slte[sessionNumLte].verbFailReason,
                         slte[sessionNumLte].verbFailReason );

                /* Clear any session ID's which may have been assigned by the SLQS API. This
                 * is required when data session for same instance is already active. */
                if( IPv4_FAMILY_PREFERENCE == IPFamilyPreference  )
                {
                    slte[sessionNumLte].v4sessionId = 0;
                }
                if( IPv6_FAMILY_PREFERENCE == IPFamilyPreference )
                {
                    slte[sessionNumLte].v6sessionId = 0;
                }
                return -1;
            }
        }

        sessionNumLte++;
        if ( sessionNumLte > MAX_INST_ID+1 )
        {
            sessionNumLte = 0;
        }
    }

    if (isCdma)
    {
        TRACE_MSG(LOG_INFO, fp, "CDMA Data Session started successfully\n" );
    }
    else
    {
        /* Technology is LTE. Display success if IPFamily is not IPv4v6. */
        if( IPv4v6_FAMILY_PREFERENCE != IPFamilyPreference )
        {
            TRACE_MSG(LOG_INFO, fp, "LTE Data Session started successfully\n" );
        }
    }

    UpdateUserDisplay( eCALL_STATUS, "CONNECTED" );
    return SUCCESS;
}


/*
 * Name:     UpdateDisplayInfo
 *
 * Purpose:  Update json file to display in Web GUI
 *
 * Params:   None
 *
 * Return:   None
 *
 * Notes:    None
 */
static void UpdateDisplayInfo()
{
    FILE *outputFile;

    outputFile = fopen ("/usr/lib/lte-cm/lte_info.json","w");
    if(outputFile == NULL)
    {
        TRACE_MSG(LOG_ERR, fp, "lte_info.json : %s\n", strerror(errno));
        return;
    }

    fprintf(outputFile, "{");
    fprintf(outputFile, "\n\t\"Status\" : \"%s\"\,", sessionOutput.status );
    fprintf(outputFile, "\n\t\"Duration\" : \"%s\"\,", sessionOutput.duration );
    fprintf(outputFile, "\n\t\"Manufacture ID\" : \"%s\"\,", sessionOutput.manufacture_id );
    fprintf(outputFile, "\n\t\"Model ID\" : \"%s\"\,", sessionOutput.model_id );
    fprintf(outputFile, "\n\t\"Firmware Revisions\" : \"%s\"\,", sessionOutput.firmware_revisions );
    fprintf(outputFile, "\n\t\"Boot Revisions\" : \"%s\"\,", sessionOutput.boot_revisions );
    fprintf(outputFile, "\n\t\"PRI Versions\" : \"%s\"\,", sessionOutput.pri_versions );
    fprintf(outputFile, "\n\t\"PRL Version\" : \"%s\"\,", sessionOutput.prl_version );
    fprintf(outputFile, "\n\t\"PRL Preference\" : \"%s\"\,", sessionOutput.prl_preference );
    fprintf(outputFile, "\n\t\"IMSI\" : \"%s\"\,", sessionOutput.imsi );
    fprintf(outputFile, "\n\t\"Hardware Revision\" : \"%s\"\,", sessionOutput.hardware_revision );
    fprintf(outputFile, "\n\t\"IPAddress\" : \"%s\"\,", sessionOutput.ip_address );
    fprintf(outputFile, "\n\t\"Subnet Mask\" : \"%s\"\,", sessionOutput.subnet_mask );
    fprintf(outputFile, "\n\t\"Gateway\" : \"%s\"\,", sessionOutput.gateway );
    fprintf(outputFile, "\n\t\"Primary DNS\" : \"%s\"\,", sessionOutput.primary_dns );
    fprintf(outputFile, "\n\t\"Secondary DNS\" : \"%s\"\,", sessionOutput.secondary_dns );
    fprintf(outputFile, "\n\t\"Radio Interface\" : \"%s\"\,", sessionOutput.radio_interface );
    fprintf(outputFile, "\n\t\"Band Class\" : \"%s\"\,", sessionOutput.band_class );
    fprintf(outputFile, "\n\t\"Active Channel\" : \"%s\"", sessionOutput.active_channel );
    fprintf(outputFile, "\n}");

    fclose(outputFile);
}


/*
 * Name:     GetDeviceinfo
 *
 * Purpose:  Get the information about the connected device
 *
 * Params:   None
 *
 * Return:   None
 *
 * Notes:    None
 */
static void GetDeviceinfo()
{
    ULONG resultCode = 0;
    CHAR  responseBuffer[RESP_BUFFER_LEN];
    CHAR  bootBuffer[RESP_BUFFER_LEN];
    CHAR  priBuffer[RESP_BUFFER_LEN];
    WORD  PRLVersion = 0;
    BYTE  PRLPreference = 0xFF;
    dmsCurrentPRLInfo CurrentPRLInfo;

    /* Reset the buffer */
    memset( responseBuffer, 0, RESP_BUFFER_LEN );

    /* Get the Device Manufacture ID */
    resultCode = GetManufacturer( RESP_BUFFER_LEN, responseBuffer );
    if( SUCCESS != resultCode )
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to get Manufacture ID : %lu\n", resultCode );
        strcpy(sessionOutput.manufacture_id, "");
    }
    else
    {
        TRACE_MSG(LOG_INFO, fp, "Manufacture ID : %s\n", responseBuffer );
        strcpy(sessionOutput.manufacture_id, responseBuffer );
    }

    /* Reset the buffer */
    memset( responseBuffer, 0, RESP_BUFFER_LEN );

    /* Get the Model ID */
    resultCode = GetModelID( RESP_BUFFER_LEN, responseBuffer );
    if( SUCCESS != resultCode )
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to get Model ID : %lu\n", resultCode );
        strcpy(sessionOutput.model_id, "");
    }
    else
    {
        TRACE_MSG(LOG_INFO, fp, "Model ID : %s\n", responseBuffer );
        strcpy(sessionOutput.model_id, responseBuffer );
    }

    /* Reset the buffer */
    memset( responseBuffer, 0, RESP_BUFFER_LEN );

    /* Get the Firmware Revision */
    resultCode = GetFirmwareRevisions( RESP_BUFFER_LEN, responseBuffer,
                                       RESP_BUFFER_LEN, bootBuffer,
                                       RESP_BUFFER_LEN, priBuffer);
    if( SUCCESS != resultCode )
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to get Firmware, Boot and PRI revisions : %lu\n", \
                    resultCode );
        strcpy(sessionOutput.firmware_revisions, "");
        strcpy(sessionOutput.boot_revisions, "");
        strcpy(sessionOutput.pri_versions, "");
    }
    else
    {
        TRACE_MSG(LOG_INFO, fp, "Firmware revisions : %s\n", responseBuffer );
        strcpy(sessionOutput.firmware_revisions, responseBuffer );
        TRACE_MSG(LOG_INFO, fp, "Boot revisions : %s\n", bootBuffer );
        strcpy(sessionOutput.boot_revisions, bootBuffer );
        TRACE_MSG(LOG_INFO, fp, "PRI versions: %s\n", priBuffer );
        strcpy(sessionOutput.pri_versions, priBuffer );
    }

    /* Reset the buffer */
    memset( responseBuffer, 0, RESP_BUFFER_LEN );

    /* Get the PRL Version */
    CurrentPRLInfo.pPRLVersion = &PRLVersion;
    CurrentPRLInfo.pPRLPreference = &PRLPreference;
    resultCode = SLQSGetCurrentPRLInfo( &CurrentPRLInfo );
    if( SUCCESS != resultCode )
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to get PRL version : %lu\n", resultCode );
        strcpy(sessionOutput.prl_version, "");
        strcpy(sessionOutput.prl_preference, "");
    }
    else
    {
        /* Copy the PRL Version into a buffer */
        sprintf ( responseBuffer, "%d", *(CurrentPRLInfo.pPRLVersion) );

        TRACE_MSG(LOG_INFO, fp, "PRL version: %s\n", responseBuffer );
        strcpy(sessionOutput.prl_version, responseBuffer );

        /* Copy the PRL Preference into a buffer */
        sprintf ( responseBuffer, "%d", *(CurrentPRLInfo.pPRLPreference) );

        TRACE_MSG(LOG_INFO, fp, "PRL preference: %s\n", responseBuffer );
        strcpy(sessionOutput.prl_preference, responseBuffer );
    }

    /* Reset the buffer */
    memset( responseBuffer, 0, RESP_BUFFER_LEN );

    /* Get the IMSI */
    resultCode = GetIMSI( RESP_BUFFER_LEN, responseBuffer );
    if( SUCCESS != resultCode )
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to get IMSI : %lu\n", resultCode );
        strcpy(sessionOutput.imsi, "");
    }
    else
    {
        TRACE_MSG(LOG_INFO, fp, "IMSI: %s\n", responseBuffer );
        strcpy(sessionOutput.imsi, responseBuffer );
    }

    /* Reset the buffer */
    memset( responseBuffer, 0, RESP_BUFFER_LEN );

    /* Get the Hardware Revision */
    resultCode = GetHardwareRevision( RESP_BUFFER_LEN, responseBuffer );
    if( SUCCESS != resultCode )
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to get Hardware revision : %lu\n", resultCode );
        strcpy(sessionOutput.hardware_revision, "");
    }
    else
    {
        TRACE_MSG(LOG_INFO, fp, "Hardware Revision: %s\n", responseBuffer );
        strcpy(sessionOutput.hardware_revision, responseBuffer);
    }
}

/*
 * Name:     GetNetworkDetails
 *
 * Purpose:  Get the IP related information
 *
 * Params:   None
 *
 * Return:   None
 *
 * Notes:    None
 */
static void GetNetworkDetails()
{
    ULONG resultCode = 0, sessionID = 0;
    CHAR  responseBuffer[RESP_BUFFER_LEN];
    struct WdsRunTimeSettings pRunTimeSettings;
    ULONG  IPAddress, primaryDNS, secondaryDNS, subnetMask, gwAddress;

    sessionID = slte[0].v4sessionId;
    memset(&pRunTimeSettings, 0, sizeof(pRunTimeSettings));
    pRunTimeSettings.v4sessionId = &sessionID;
    TRACE_MSG( LOG_INFO, fp, "Session id = %u\n",  *(pRunTimeSettings.v4sessionId));
    pRunTimeSettings.v6sessionId = NULL;
    /*Need to assign the memory to read the values*/
    pRunTimeSettings.rts.pIPAddressV4 = &IPAddress;
    pRunTimeSettings.rts.pSubnetMaskV4 = &subnetMask;
    pRunTimeSettings.rts.pGWAddressV4 = &gwAddress;
    pRunTimeSettings.rts.pPrimaryDNSV4 = &primaryDNS;
    pRunTimeSettings.rts.pSecondaryDNSV4 = &secondaryDNS;
    resultCode = SLQSGetRuntimeSettings(&pRunTimeSettings);
    if(SUCCESS != resultCode)
    {
        TRACE_MSG(LOG_ERR, fp, "SLQSGetRuntimeSettings failed, return code = %u\n",  resultCode);
        strcpy(sessionOutput.ip_address, "");
        strcpy(sessionOutput.subnet_mask, "");
        strcpy(sessionOutput.gateway, "");
        strcpy(sessionOutput.primary_dns, "");
        strcpy(sessionOutput.secondary_dns, "");
    }
    else
    {
        memset( responseBuffer, 0, RESP_BUFFER_LEN );
        IPUlongToDot(*(pRunTimeSettings.rts.pIPAddressV4), &responseBuffer);
        TRACE_MSG(LOG_INFO, fp, "IPAddress = %s\n", responseBuffer);
        strcpy(sessionOutput.ip_address, responseBuffer );

        memset( responseBuffer, 0, RESP_BUFFER_LEN );
        IPUlongToDot(*(pRunTimeSettings.rts.pSubnetMaskV4), &responseBuffer);
        TRACE_MSG(LOG_INFO, fp, "Subnet Mask = %s\n", responseBuffer);
        strcpy(sessionOutput.subnet_mask, responseBuffer );

        memset( responseBuffer, 0, RESP_BUFFER_LEN );
        IPUlongToDot(*(pRunTimeSettings.rts.pGWAddressV4), &responseBuffer);
        TRACE_MSG(LOG_INFO, fp, "Gateway = %s\n", responseBuffer);
        strcpy(sessionOutput.gateway, responseBuffer );

        memset( responseBuffer, 0, RESP_BUFFER_LEN );
        IPUlongToDot(*(pRunTimeSettings.rts.pPrimaryDNSV4), &responseBuffer);
        TRACE_MSG(LOG_INFO, fp, "Primary DNS = %s\n", responseBuffer);
        strcpy(sessionOutput.primary_dns, responseBuffer );

        memset( responseBuffer, 0, RESP_BUFFER_LEN );
        IPUlongToDot(*(pRunTimeSettings.rts.pSecondaryDNSV4), &responseBuffer);
        TRACE_MSG(LOG_INFO, fp, "Secondary DNS = %s\n", responseBuffer);
        strcpy(sessionOutput.secondary_dns, responseBuffer );
    }
}

/*************************************************************************
 * Application starting and SDK initialization functions.
 ************************************************************************/
/*
 * Name:     StartSDK
 *
 * Purpose:  It starts the SDK by setting the SDK path, enumerates the device
 *           and connects to the SDK.
 *
 * Params:   None
 *
 * Return:   SUCCESS on successfully starting SDK, else error code
 *
 * Notes:    None
 */
ULONG StartSDK(BYTE modem_index)
{
    ULONG resultCode  = 0;
    BYTE  devicesSize = 1;

    /* Set SDK image path */
    if( SUCCESS != (resultCode = SetSDKImagePath(sdkbinpath)) )
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to set SDK image path : %lu", resultCode);
        return resultCode;
    }

    /* Establish APP<->SDK IPC */
    if( SUCCESS != (resultCode = SLQSStart(modem_index, NULL)) )
    {
        /* first attempt failed, kill SDK process */
        if( SUCCESS != (resultCode = SLQSKillSDKProcess() ))
        {
            TRACE_MSG(LOG_ERR, fp, "Failed to kill SDK process: %lu", resultCode);
            return resultCode;
        }
        else
        {
            /* start new SDK process */
            if( SUCCESS != (resultCode = SLQSStart(modem_index, NULL)) )
            {
                TRACE_MSG(LOG_ERR, fp, "Failed to start new SDK process : %lu", resultCode);
                return resultCode;
            }
        }
    }

    /* Enumerate the device */
    while (QCWWAN2kEnumerateDevices(&devicesSize, (BYTE *)pdev) != 0)
    {
        TRACE_MSG(LOG_ERR, fp, "\nUnable to find device..\n");
        sleep(1);
    }

    #ifdef DBG
    fprintf( stderr,  "#devices: %d\ndeviceNode: %s\ndeviceKey: %s\n",
            devicesSize,
            pdev->deviceNode,
            pdev->deviceKey );
    #endif

    /* Connect to the SDK */
    resultCode = QCWWANConnect( pdev->deviceNode,
                                pdev->deviceKey );
    return resultCode;
}


/*
 * Name:    SignalSetup
 *
 * Purpose: Register functions to handle signals
 *
 * Params:  None
 *
 * Return:  None
 *
 * Notes:   None
 *
 */

void SignalSetup()
{
   signal(SIGTERM, QuitApplication);
   signal(SIGINT, QuitApplication);
}


/*
 * Name:     main
 *
 * Purpose:  Entry point of the application
 *
 * Params:   None
 *
 * Return:   EXIT_SUCCESS, EXIT_FAILURE on unexpected error
 *
 * Notes:    None
 */
int main( int argc, const char *argv[])
{
    FILE *inputFile = NULL;
    int value;
    BYTE modem_index, IPFamilyPreference = IPv4_FAMILY_PREFERENCE, instance_size = MAX_INST_ID;
    ULONG resultCode = 0, profileID = 1, duration = 0;
    CHAR profile_buffer[MAX_LENGTH], command[MAX_LENGTH], responseBuffer[MAX_LENGTH];
    struct stat fileAttribute;
    struct RFBandInfoElements RFBand_details;
    struct ProfileDetails profileDetails;

    /* Initializing profileDetails with default values */
    profileDetails.IPFamilyPreference = 4;
    profileDetails.PDPType = 0;
    profileDetails.authenticationValue = 0;
    memset(profileDetails.connectionType, 0, MAX_FIELD_SIZE);
    memset(profileDetails.IPAddress, 0, MAX_FIELD_SIZE);
    memset(profileDetails.primaryDNS, 0, MAX_FIELD_SIZE);
    memset(profileDetails.secondaryDNS, 0, MAX_FIELD_SIZE);
    memset(profileDetails.profileName, 0, MAX_PROFILE_NAME_SIZE);
    memset(profileDetails.APNName, 0, MAX_APN_SIZE);
    memset(profileDetails.userName, 0, MAX_USER_NAME_SIZE);
    memset(profileDetails.password, 0, MAX_FIELD_SIZE);


    /* Setting default values to lte_info.json display file */
    memset(&sessionOutput, 0, sizeof(sessionOutput));
    UpdateDisplayInfo();

    openlog("connectionmgr", LOG_PID, LOG_DAEMON);
    fp = fopen("/var/log/sierracm", "a+");

    if(fp == NULL)
    {
       syslog(LOG_ERR, "/var/log/sierracm: %s\n", strerror(errno));
       return EXIT_FAILURE;
    }

    if( argc < 3 )
    {
        TRACE_MSG(LOG_INFO, fp, "usage: %s <path to sdk binary> <modem_index>\n", argv[0] );
        TRACE_MSG(LOG_INFO, fp, "where modem_index start from 0\n");
        return EXIT_FAILURE;
    }

    if(stat("/usr/bin/lte_apn_setup.sh", &fileAttribute) < 0)
    {
        TRACE_MSG(LOG_ERR, fp, "/usr/bin/lte_apn_setup.sh : %s\n", strerror(errno));
        return EXIT_FAILURE;
    }
    snprintf(command, MAX_LENGTH, "/usr/bin/lte_apn_setup.sh ");
    TRACE_MSG(LOG_INFO, fp, "calling : %s", command);
    if((resultCode = system(command)) != 0)
    {
        TRACE_MSG(LOG_ERR, fp, "lte_apn_setup.sh script call failed : %lu\n", resultCode);
        return EXIT_FAILURE;
    }

    if( NULL == (sdkbinpath = malloc(strlen(argv[1]) + 1)) )
    {
        TRACE_MSG(LOG_ERR, fp, "Error: sdkbinpath not defined\n");
        return EXIT_FAILURE;
    }

    strncpy( sdkbinpath, argv[1], strlen(argv[1]) + 1);

    value = atoi(argv[2]);
    if (
            (value < 0)
            || (value > 8)
       )
    {
        TRACE_MSG(LOG_ERR, fp, "cannot convert second param into modem_index\n");
        return EXIT_FAILURE;
    }
    modem_index = value;

    SignalSetup();

    /* Start the SDK */
    resultCode = StartSDK(modem_index);

    if( SUCCESS != resultCode )
    {
        free(sdkbinpath);

        /* Display the failure reason */
        TRACE_MSG(LOG_ERR, fp, "Failed to start SDK : %lu Exiting App\n", resultCode );

        /* Failed to start SDK, exit the application */
        return EXIT_FAILURE;
    }


    /* Subscribe to all the required callbacks */
    SubscribeCallbacks();

    inputFile = fopen("/usr/lib/lte-cm/profiles.txt", "r");
    if(inputFile == NULL)
    {
        if(errno != 2)
        {
            TRACE_MSG(LOG_ERR, fp, "profiles.txt : %s\n", strerror(errno));
            return EXIT_FAILURE;
        }
        TRACE_MSG(LOG_INFO, fp, "Connecting using default profile");
    }
    else
    {
        if(fgets(profile_buffer, MAX_LENGTH, inputFile) != NULL)
        {
            if(sscanf(profile_buffer,"%s %u %u %s %s %s %u %s %s %s %s", profileDetails.connectionType, \
                                     &profileDetails.IPFamilyPreference, &profileDetails.PDPType, profileDetails.IPAddress, \
                                     profileDetails.primaryDNS, profileDetails.secondaryDNS, &profileDetails.authenticationValue, \
                                     profileDetails.profileName, profileDetails.APNName, profileDetails.userName, \
                                     profileDetails.password) < 7)
            {
               TRACE_MSG(LOG_ERR, fp, "profiles.txt: %s invalid table entry\n", profile_buffer);
               return EXIT_FAILURE;
            }

            strtok(profileDetails.password, "\n");
        }
        fclose(inputFile);

        if(strcmp(profileDetails.connectionType, "LTE") != 0)
        {
            TRACE_MSG(LOG_ERR, fp, "Invalid Connection Type\n");
            TRACE_MSG(LOG_INFO, fp, "Valid Connection Type : LTE\n");
            return EXIT_FAILURE;
        }

        if( (profileDetails.IPFamilyPreference != 4) && (profileDetails.IPFamilyPreference != 6) \
            && (profileDetails.IPFamilyPreference != 7))
        {
            TRACE_MSG(LOG_ERR, fp, "Invalid IP Family\n");
            TRACE_MSG(LOG_INFO, fp, "Valid IP Family values : 4 - IPv4, 6 - IPv6, 7 - IPv4v6\n");
            return EXIT_FAILURE;
        }
        DisplayAllProfile();
        TRACE_MSG(LOG_INFO, fp, "Deleting existing profiles from device\n");
        DeleteProfilesFromDevice();

        TRACE_MSG(LOG_INFO, fp, "Adding new profile with the below profile details\n");
        TRACE_MSG(LOG_INFO, fp, "ConnectionType : %s \n", profileDetails.connectionType);
        TRACE_MSG(LOG_INFO, fp, "IPFamilyPreference : %u \n", profileDetails.IPFamilyPreference);
        TRACE_MSG(LOG_INFO, fp, "PDPType : %u \n", profileDetails.PDPType);
        TRACE_MSG(LOG_INFO, fp, "IPAddress : %s \n", profileDetails.IPAddress);
        TRACE_MSG(LOG_INFO, fp, "PrimaryDNS : %s \n", profileDetails.primaryDNS);
        TRACE_MSG(LOG_INFO, fp, "SecondaryDNS : %s \n", profileDetails.secondaryDNS);
        TRACE_MSG(LOG_INFO, fp, "AuthenticationValue : %u \n", profileDetails.authenticationValue);
        TRACE_MSG(LOG_INFO, fp, "ProfileName : %s \n", profileDetails.profileName);
        TRACE_MSG(LOG_INFO, fp, "APNName : %s \n", profileDetails.APNName);
        TRACE_MSG(LOG_INFO, fp, "UserName : %s \n", profileDetails.userName);
        TRACE_MSG(LOG_INFO, fp, "Password : %s \n", profileDetails.password);

        resultCode = 0;
        resultCode = CreateProfile(&profileDetails);

        if(resultCode != SUCCESS)
        {
            TRACE_MSG(LOG_ERR, fp, "Profile creation failed\n");
            return EXIT_FAILURE;
        }

        profileID = 2;
        IPFamilyPreference = profileDetails.IPFamilyPreference;
        TRACE_MSG(LOG_INFO, fp, "Conneting using given profile");
    }
    resultCode = 0;
    resultCode = StartLteCdmaDataSession(0, profileID, IPFamilyPreference);
    if(resultCode != SUCCESS)
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to start Data Session : %lu", resultCode);
        return EXIT_FAILURE;
    }

    strcpy(sessionOutput.status, "connected");

    resultCode = GetRFInfo(&instance_size, &RFBand_details);
    if(resultCode != SUCCESS)
    {
        TRACE_MSG(LOG_ERR, fp, "Failed to get RF Band Info : %lu", resultCode);
        return EXIT_FAILURE;
    }

    /* Get the information about the connected device */
    GetDeviceinfo();
    GetNetworkDetails();

    RFInfoCallback(RFBand_details.radioInterface, RFBand_details.activeBandClass, \
                    RFBand_details.activeChannel);

    while(1)
    {
        sleep(1);
        resultCode = GetSessionDuration(&duration, 0);
        if(resultCode != SUCCESS)
        {
            TRACE_MSG(LOG_ERR, fp, "Failed to get Session Duration : %lu", resultCode);
            strcpy(sessionOutput.duration, "");
        }
        else
        {
            sprintf(responseBuffer, "%lu days %lu hrs %lu mins %lu secs", ((duration / (1000*60*60)) / 24), \
                    ((duration / (1000*60*60)) % 24), ((duration / (1000*60)) % 60), ((duration / 1000) % 60));
            strcpy(sessionOutput.duration, responseBuffer);
        }
        UpdateDisplayInfo();
    }
}
