#include <semaphore.h>

int sem_initD(sem_t* sem, unsigned int value) {
  return sem_init(sem, 0, value);
}

#define sem_incr sem_post

// int sem_incr(sem_t* sem){
//     return sem_post(sem);
// }
