# Makefile

CC = gcc
CFLAGS = -Wall -Wextra -O2
TARGET = noti
SRC = noti.c

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)

clean:
	rm -f $(TARGET)