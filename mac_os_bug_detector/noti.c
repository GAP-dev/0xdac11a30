#include <stdio.h>
#include <stdlib.h>
#include <dirent.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <time.h>

#define FOLDER_PATH "/Users/gap_dev/Library/Logs/DiagnosticReports"
#define POLL_INTERVAL 5              // seconds
#define MAX_FILES 200                // 최대 파일 수
#define FILE_NAME_LEN 256

typedef struct {
    char name[FILE_NAME_LEN];
    time_t mod_time;
} FileInfo;

int scan_folder(FileInfo* files, int max_files) {
    DIR* dir = opendir(FOLDER_PATH);
    if (!dir) {
        perror("폴더 열기 실패");
        return -1;
    }

    struct dirent* entry;
    int count = 0;
    while ((entry = readdir(dir)) && count < max_files) {
        if (entry->d_type == DT_REG) {
            struct stat st;
            char fullpath[512];
            snprintf(fullpath, sizeof(fullpath), "%s/%s", FOLDER_PATH, entry->d_name);
            if (stat(fullpath, &st) == 0) {
                strncpy(files[count].name, entry->d_name, FILE_NAME_LEN - 1);
                files[count].name[FILE_NAME_LEN - 1] = '\0'; // null-terminate
                files[count].mod_time = st.st_mtime;
                count++;
            }
        }
    }

    closedir(dir);
    return count;
}

// 파일이 prev 리스트에 있는지 확인
int is_new_file(const FileInfo* prev, int prev_count, const char* name) {
    for (int i = 0; i < prev_count; i++) {
        if (strcmp(prev[i].name, name) == 0) {
            return 0;  // 이미 존재
        }
    }
    return 1;  // 새 파일
}

void escape_quotes(char* dest, const char* src, size_t max_len) {
    size_t j = 0;
    for (size_t i = 0; src[i] != '\0' && j < max_len - 1; i++) {
        if (src[i] == '\"') {
            if (j < max_len - 2) {
                dest[j++] = '\\';
                dest[j++] = '\"';
            }
        } else {
            dest[j++] = src[i];
        }
    }
    dest[j] = '\0';
}

void send_notification(const char* message) {
    char escaped[512];
    escape_quotes(escaped, message, sizeof(escaped));

    char cmd[600];
    snprintf(cmd, sizeof(cmd),
        "osascript -e 'display notification \"%s\" with title \"Crash Watcher\"'",
        escaped);
    system(cmd);
}

int main() {
    FileInfo prev[MAX_FILES], curr[MAX_FILES];
    int prev_count = scan_folder(prev, MAX_FILES);

    if (prev_count < 0) return 1;

    printf("🔍 시작: %d개 파일 감지됨\n", prev_count);

    while (1) {
        sleep(POLL_INTERVAL);
        int curr_count = scan_folder(curr, MAX_FILES);
        if (curr_count < 0) continue;

        for (int i = 0; i < curr_count; i++) {
            if (is_new_file(prev, prev_count, curr[i].name)) {
                char message[300];
                snprintf(message, sizeof(message), "Crash file detected: %s", curr[i].name);
                printf("🚨 %s\n", message);
                send_notification(message);
            }
        }

        memcpy(prev, curr, sizeof(FileInfo) * curr_count);
        prev_count = curr_count;
    }

    return 0;
}