#include <stdlib.h>
#include <string.h>
#include <stdio.h>

typedef struct {
    char buffer[32];
} Payload;

int main() {
    Payload *p = malloc(sizeof(Payload));
    strcpy(p->buffer, "Hello, world!");
    free(p);

    // write after free
    strcpy(p->buffer, "Poison this!");  // 💥

    return 0;
}
