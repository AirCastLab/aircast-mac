//
//  main.m
//  aircast-demo
//
//  Created by xiang on 18/03/2018.
//  Copyright © 2018 dotEngine. All rights reserved.
//

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <sys/stat.h>


#import <aircast_sdk_mac/acast_c.h>

#import <Foundation/Foundation.h>


//file tools
FILE* fOpen(const char* name, const char* mode)
{
    return fopen(name, mode);
}

ssize_t fRead(FILE* fp, void* buffer, size_t bytes_to_read)
{
    size_t len = fread(buffer, 1, bytes_to_read, fp);
    if (len < bytes_to_read)
    {
        if (ferror(fp))
            return -1;
    }
    return len;
}

ssize_t fWrite(FILE* fp, const void* buffer, size_t bytes_to_write)
{
    size_t len = fwrite(buffer, 1, bytes_to_write, fp);
    if (len < bytes_to_write)
    {
        if (ferror(fp))
            return -1;
    }
    return len;
}

//TODO: change to a proper path in your computer
static uint32_t s_ACounter = 0;
static uint32_t s_VCounter = 0;
static FILE* s_AudioFP = NULL;
static FILE* s_VideoFP = NULL;
static FILE* s_AudioLogFP = NULL;
static FILE* s_VideoLogFP = NULL;

#define MAX_FN_BUF_LEN 256
#define LOG_LINE_BUF_SIZE 64

static char s_savePath[MAX_FN_BUF_LEN] = {0}; //shall be at: ~/Desktop/aircast_save/

static void init_save_path()
{
    //always under desktop/aircast_save/
    snprintf(s_savePath, MAX_FN_BUF_LEN, "%s/Desktop/aircast_save/", getenv("HOME"));
    if (mkdir(s_savePath, 0770) != 0 && errno != EEXIST)
    {
        printf( "failed to create save path.\n");
        exit(0);
    }
}

static void openAudioDataFile()
{
    char fn[MAX_FN_BUF_LEN];
    
    if( s_AudioFP != NULL)
    {
        fclose(s_AudioFP);
    }
    snprintf(fn, MAX_FN_BUF_LEN, "%saudio_%d.pcm", s_savePath, s_ACounter);
    s_AudioFP = fOpen(fn, "wb");
    //ASSERT(s_AudioFP != NULL);
    
    if (s_AudioLogFP != NULL)
    {
        fclose(s_AudioLogFP);
    }
    snprintf(fn, MAX_FN_BUF_LEN, "%saudio_%d.log", s_savePath, s_ACounter++);
    s_AudioLogFP = fOpen(fn, "w");
    //ASSERT(s_AudioLogFP != NULL);
    
    return;
}

static void openVideoDataFile()
{
    char fn[MAX_FN_BUF_LEN];
    
    if (s_VideoFP != NULL)
    {
        fclose(s_VideoFP);
    }
    
    snprintf(fn, MAX_FN_BUF_LEN, "%svideo_%d.h264", s_savePath, s_VCounter);
    s_VideoFP = fOpen(fn, "wb");
    //ASSERT(s_VideoFP != NULL);
    
    if (s_VideoLogFP != NULL)
    {
        fclose(s_VideoLogFP);
    }
    snprintf(fn, MAX_FN_BUF_LEN, "%svideo_%d.log", s_savePath, s_VCounter++);
    s_VideoLogFP = fOpen(fn, "w");
    //ASSERT(s_VideoLogFP != NULL);
    
    return;
}

//callback
static int ac_callback(EACMsgType eType, void* data, size_t dataSize, void* opaque)
{
    switch (eType)
    {
        case eACMsgType_Error:
        {
            SACErrorInfo * eInfo = (SACErrorInfo*)data;
            //ASSERT(dataSize == sizeof(SACErrorInfo));
            printf("error occurs: %s\n", eInfo->info);
        }
            break;
        case eACMsgType_Info:
            break;
        case eACMsgType_Connected:
        {
            SACConnectedInfo * conInfo = (SACConnectedInfo*)data;
            //ASSERT(dataSize == sizeof(SACConnectedInfo));
            printf("new connection: name: %s; ip: %s; deviceID: %s, model: %s\n",
                   conInfo->peerName, conInfo->peerIPAddr, conInfo->peerDeviceID, conInfo->peerModel);
        }
            break;
        case eACMsgType_MediaDesc:
        {
            SACMediaDescInfo * info = (SACMediaDescInfo*)data;
            //ASSERT(dataSize == sizeof(SACMediaDescInfo));
            printf("New media starting...\n");
            switch (info->mediaType)
            {
                case eACMediaType_VideoStream:
                    printf("video stream: width: %d; height: %d, rotate: %d, extraDataSize: %d\n",
                           info->info.videoStream.width, info->info.videoStream.height, info->info.videoStream.rotate, info->info.videoStream.extraDataSize);
                    break;
                case eACMediaType_AudioFrame:
                    printf("audio stream: sampleRate: %d; channels: %d\n",
                           info->info.audioFrame.sampleRate, info->info.audioFrame.channels);
                    break;
                default:
                    break;
            }
        }
            break;
        case eACMsgType_Disconnected:
        {
            SACDisconnectInfo * info = (SACDisconnectInfo*)data;
            //ASSERT(dataSize == sizeof(SACDisconnectInfo));
            switch (info->streamType)
            {
                case eACStreamType_All:
                    printf("current session reset.\n");
                    break;
                case eACStreamType_Video:
                    printf("video session reset.\n");
                    break;
                case eACStreamType_Audio:
                    printf("audio session reset.\n");
                    break;
                default:
                    break;
            }
        }
            break;
        case eACMsgType_VideoData:
        {
            SACAVDataInfo * info = (SACAVDataInfo*)data;
            //ASSERT(dataSize == sizeof(SACAVDataInfo));
            if (info->flags & ACAVDATA_FLAG_NEWFORMAT)
            {
                ////////
                printf("new video segment\n");
                openVideoDataFile();
            }
            fWrite(s_VideoFP, info->data, info->dataSize);
            
            ////
            char log_line[LOG_LINE_BUF_SIZE];
            size_t len = snprintf(log_line, LOG_LINE_BUF_SIZE, "%lld, flag: %d\n", info->ts, info->flags);
            fWrite(s_VideoLogFP, log_line, len);
        }
            break;
        case eACMsgType_AudioData:
        {
            SACAVDataInfo * info = (SACAVDataInfo*)data;
            //ASSERT(dataSize == sizeof(SACAVDataInfo));
            
            if (info->flags & ACAVDATA_FLAG_NEWFORMAT)
            {
                ////////
                printf("new audio segment\n");
                openAudioDataFile();
            }
            fWrite(s_AudioFP, info->data, info->dataSize);
            
            ////
            char log_line[LOG_LINE_BUF_SIZE];
            size_t len = snprintf(log_line, LOG_LINE_BUF_SIZE, "%lld, flag: %d\n", info->ts, info->flags);
            fWrite(s_AudioLogFP, log_line, len);
        }
            break;
        case eACMsgType_LicenseRequest:
        {
            char fn[MAX_FN_BUF_LEN];
            char licStr[1024];
            //To send license Request
            printf("license request\n");
            snprintf(fn, MAX_FN_BUF_LEN, "%slic.txt", s_savePath);
            
            FILE* fp = fOpen(fn, "rt");
            if (fp == NULL)
                break;
            
            size_t len = fRead(fp, licStr, 1024);
            //ASSERT(len < 1024);
            licStr[len] = '\0';
            fclose(fp);
            
            //to install license
            ac_update_license(licStr);
        }
            break;
    }
    
    return 1;
}



int main(int argc, const char * argv[]) {
    ////
    init_save_path();
    
    //simply
    int ret = ac_setup(ac_callback, NULL);
    if (ret != AC_OK)
    {
        printf("failed to setup, return: %d\n", ret);
    }
    
    //params
    SACStartParams params;
    params.broadcastName = "aircast_sdk_test";
    params.enableAudio = true;
    params.eVideoOutputResOption = eACResOpt_Auto;
    //params.eVideoOutputResOption = eACResOpt_480;
    
    ret = ac_start(&params);
    if (ret != AC_OK)
    {
        printf("failed to start, ret: %d\n", ret);
    }
    
    printf("start to receive connection, press q to exit.\n");
    while( true)
    {
        if( fgetc(stdin) == 'q')
            break;
    }
    
    printf("exiting \n");
    
    ac_stop();
    ac_finalize();
    
    if (s_AudioFP != NULL) fclose(s_AudioFP);
    if (s_AudioLogFP != NULL) fclose(s_AudioLogFP);
    if (s_VideoFP != NULL) fclose(s_VideoFP);
    if (s_VideoLogFP != NULL) fclose(s_VideoLogFP);
    return 0;
}
