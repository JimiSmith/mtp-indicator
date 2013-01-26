#include <stdio.h>
#include <stdlib.h>
#include <mntent.h>
#include <stdbool.h>

bool is_directory_mounted(char* name) {
  struct mntent *ent;
  FILE *aFile;

  aFile = setmntent("/proc/mounts", "r");
  if (aFile == NULL) {
    perror("setmntent");
    exit(1);
  }
  bool is_mounted = false;
  while (NULL != (ent = getmntent(aFile))) {
    is_mounted = strcmp(name, ent->mnt_dir) == 0;
    if (is_mounted) {
      break;
    }
  }
  endmntent(aFile);
  return is_mounted;
}