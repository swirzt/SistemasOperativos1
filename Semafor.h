#include <stdlib.h>
struct semaphore_t{int s;};

typedef struct semaphore_t sem_t;

/* Función de creación de Semáforo */
int sem_init(sem_t *sem, int init){
    return sem->s=init;
}

/* Incremento del semáforo. */
int sem_incr(sem_t *sem){
    return sem->s++;
}

/* Decremento del semáforo. Notar que es una función que puede llegar a bloquear
   el proceso.*/
int sem_decr(sem_t *sem){
    int sembackup = sem->s;
    sem->s--;
    if (sem->s < 0) while (sem->s < sembackup); // Si sem->s-- es negativo espero a que aumente 1
    // Tiene problemas de prioridad
    return 0;
}

/* Destrucción de un semáforo */
int sem_destroy(sem_t *sem){
    free(sem);
    return 0;
}

