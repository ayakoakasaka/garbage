
#include <stdint.h>
#include <stdio.h>

#if defined(__wasm__)
/* for some reasons, __builtin_setjmp/__builtin_longjmp is not used */
typedef void *jmp_buf;
int setjmp(jmp_buf env);
void longjmp(jmp_buf env, int val);
#else
typedef void *jmp_buf;
#define setjmp __builtin_setjmp
#define longjmp __builtin_longjmp
#endif

/*
 * note: a jmp_buf for __builtin_setjmp is of 5 words
 * https://gcc.gnu.org/onlinedocs/gcc/Nonlocal-Gotos.html
 * https://llvm.org/docs/ExceptionHandling.html#llvm-eh-sjlj-setjmp
 */
void *buf1[5];
void *buf2[5];

__attribute__((noinline)) void
g(jmp_buf buf, int x)
{
        if (x == 0) {
                printf("just returning\n");
                return;
        }
        printf("calling longjmp\n");
        longjmp(buf, 1);
        printf("longjmp returned\n");
}

__attribute__((noinline)) void
f(jmp_buf buf, int x)
{
        printf("calling g\n");
        g(buf, x);
        printf("g returned\n");
}

int count = 5;

void
loop()
{
        int ret = setjmp(buf2);
        printf("setjmp(buf2) returned %d\n", ret);
        if (ret == 0) {
                printf("calling f\n");
                f(buf2, 1);
                printf("f returned\n");
        }
        if (--count > 0) {
                printf("count %u\n", count);
                f(buf2, 1);
        }
}

int
main()
{
        printf("calling setjmp\n");
        int ret = setjmp(buf1);
        printf("setjmp(buf1) returned %d\n", ret);
        if (ret == 0) {
                loop();
                printf("calling f\n");
                f(buf1, 0);
                printf("f returned\n");
                printf("calling f\n");
                f(buf1, 1);
                printf("f returned\n");
        }
        printf("done\n");
}
