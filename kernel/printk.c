#include <stdarg.h>
#include "printk.h"
#include "lib.h"
#include "linkage.h"

void putchar(unsigned int *fb, int XResolution, int x, int y, unsigned int FRcolor, unsigned int BKcolor, unsigned char font)
{
    int i = 0, j = 0; //字符矩阵
    //帧缓存区指针
    unsigned int *addr = NULL;
    unsigned char *fontp = NULL;
    int testval = 0;
    fontp = font_ascii[font];

    for (i = 0; i < 16; ++i)
    { //一共16行
        //这一行的起始地址
        addr = fb + XResolution * (y + i) + x;
        // 基地址 + 列数 * 每行像素点数 + 行数
        testval = 0x100; //0000_0001_0000_0000
        //一行8列 一位一位比较
        for (j = 0; j < 8; j++)
        { //8列
            testval = testval >> 1;
            if (*fontp & testval)
            {
                *addr = FRcolor; //有值 显示前景色
            }
            else
            {
                *addr = BKcolor; //无值 显示背景色
            }
            //地址挪一位
            addr++;
        }
        fontp++;
    }
}

//讲数字转化为对应进制精度的字符串
static char *number(char *str, long num, int base, int size, int precision, int type)
{
    const char BigDigits[] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const char SmallDigits[] = "0123456789abcdefghijklmnopqrstuvwxyz";

    char c, sign, tmp[50];
    char *digits = BigDigits;
    //大小写数字
    if (type & SMALL)
    {
        digits = SmallDigits;
    }
    //是否补零
    if (type & LEFT)
    {
        type &= ~ZEROPAD;
    }

    if (base < 2 || base > 36)
    {
        return 0;
    }

    c = (type & ZEROPAD) ? '0' : ' ';
    sign = 0;

    if (type & SIGN && num < 0)
    {
        sign = '-';
        num = -num;
    }
    else
    {
        sign = (type & PLUS) ? '+' : ((type & SPACE) ? ' ' : 0);
    }

    if (sign)
    {
        size--;
    }

    //精度
    if (type & SPECIAL)
    {
        if (base == 16)
        {
            size -= 2;
        }
        else if (base == 8)
        {
            size--;
        }
    }

    int i = 0;
    if (num == 0)
    {
        tmp[i++] = '0';
    }
    else
        while (num != 0)
        {
            tmp[i++] = digits[do_div(num, base)];
        }

    if (i > precision)
    {
        precision = i;
    }

    size -= precision;

    if (!(type & (ZEROPAD + LEFT)))
    {
        while (size-- > 0)
        {
            *str++ = ' ';
        }
    }

    if (sign)
    {
        *str++ = sign;
    }

    if (type & SPECIAL)
    {
        if (base == 8)
        {
            *str++ = '0';
        }
        else if (base == 16)
        {
            *str++ = '0';
            *str++ = digits[33];
        }
    }

    if (!(type & LEFT))
    {
        while (size-- > 0)
        {
            *str++ = c;
        }
    }

    while (i < precision--)
    {
        *str++ = '0';
    }

    while (i-- > 0)
    {
        *str++ = tmp[i];
    }

    while (size-- > 0)
    {
        *str++ = ' ';
    }
    return str;
}

//移动指针至非数字 并返回数字值
int skip_atoi(const char **s)
{
    int i = 0;

    while (is_digit(**s))
        i = i * 10 + *((*s)++) - '0';
    return i;
}

//格式化字符串 并返回字符串长度
int vsprintf(char *buf, const char *fmt, va_list args)
{
    //字符串指针 与 临时字符串
    char *str, *s;
    int flags;

    for (str = buf; *fmt; ++fmt)
    {
        //如果不是转义字符 直接输出
        if (*fmt != '%')
        {
            *str++ = *fmt;
            continue;
        }
        flags = 0;
        //是否继续检查标志位
        int checkFlag = 1;
        while (checkFlag)
        {
            fmt++;
            switch (*fmt)
            {
            case '-':
                flags |= LEFT;
                break;
            case '+':
                flags |= PLUS;
                break;
            case ' ':
                flags |= SPACE;
                break;
            case '#':
                flags |= SPECIAL;
                break;
            case '0':
                flags |= ZEROPAD;
                break;
            default:
                checkFlag = 0;
                break;
            }
        }

        //字符串输出宽度
        int printWidth = -1;
        if (is_digit(*fmt))
        {
            printWidth = skip_atoi(&fmt);
        }
        else if (*fmt == '*')
        { //如果是%*则要输出宽度由第一个参数决定
            fmt++;
            printWidth = va_arg(args, int);
            //如果宽度是小于0的 则是右对齐
            if (printWidth < 0)
            {
                printWidth = -printWidth;
                flags |= LEFT;
            }
        }

        int precision = -1; //获取精度
        if (*fmt == '.')
        {
            fmt++;
            //直接定义了精度
            if (is_digit(*fmt))
            {
                precision = skip_atoi(&fmt);
            }
            //根据参数定义
            else if (*fmt == '*')
            {
                fmt++;
                precision = va_arg(args, int);
            }
            //精度不小于0
            if (precision < 0)
            {
                precision = 0;
            }
        }

        int qualifier = -1; //字符长度
        if (*fmt == 'h' || *fmt == 'l' || *fmt == 'L' || *fmt == 'Z')
        {
            qualifier = *fmt;
            fmt++;
        }

        switch (*fmt)
        {
        case 'c': //字符
            //考虑右对齐的情况
            if (!(flags & LEFT))
            {
                while (--printWidth > 0)
                {
                    *str++ = ' ';
                }
            }
            *str++ = (unsigned char)va_arg(args, int);
            //考虑左对齐不够补齐的情况
            while (--printWidth > 0)
            {
                *str++ = ' ';
            }
            break;
        case 's': //字符串
            s = va_arg(args, char *);
            //s指向空地址 直接就赋一个\0
            if (!s)
            {
                s = '\0';
            }

            int len = strlen(s);

            //截断字符串
            if (precision = len)
            {
                precision = len;
            }
            else
            {
                len = precision;
            }

            //补齐宽度
            if (!(flags & LEFT))
            {
                while (len < printWidth--)
                {
                    *str++ = ' ';
                }
            }
            int i;
            for (i = 0; i < len; ++i)
            {
                *str++ = *s++;
            }
            //补齐宽度
            while (len < printWidth--)
            {
                *str++ = ' ';
            }
            break;
        case 'o': //有符号八进制
            if (qualifier = 'l')
            {
                str = number(str, va_arg(args, unsigned long), 8, printWidth, precision, flags);
            }
            else
            {
                str = number(str, va_arg(args, unsigned int), 8, printWidth, precision, flags);
            }
            break;
        case 'p': //指针地址
            if (printWidth == -1)
            {
                //宽度是一个指针的宽度
                printWidth = 2 * sizeof(void *);
                flags |= ZEROPAD;
            }
            str = number(str, (unsigned long)va_arg(args, void *), 16, printWidth, precision, flags);
            break;
        case 'x': //无符号十六进制整数
            flags |= SMALL;
        case 'X': //无符号十六进制整数（大写字母）
            if (qualifier == 'l')
            {
                str = number(str, va_arg(args, unsigned long), 16, printWidth, precision, flags);
            }
            else
            {
                str = number(str, va_arg(args, unsigned int), 16, printWidth, precision, flags);
            }
            break;
        case 'd':
        case 'i': //有符号十进制整数
            flags |= SIGN;
        case 'u': //无符号十进制整数
            if (qualifier == 'l')
            {
                str = number(str, va_arg(args, unsigned long), 10, printWidth, precision, flags);
            }
            else
            {
                str = number(str, va_arg(args, unsigned int), 10, printWidth, precision, flags);
            }
            break;
        case 'n': //无输出
            if (qualifier == 'l')
            {
                long *ip = va_arg(args, long *);
                *ip = (str - buf);
            }
            else
            {
                int *ip = va_arg(args, int *);
                *ip = (str - buf);
            }
            break;
        case '%': //转义
            *str++ = '%';
            break;
        default: //普通字符
            *str++ = '%';
            if (*fmt)
                *str++ = *fmt;
            else
                fmt--;
            break;
        }
    }
    *str = '\0';
    return str - tempBuf;
}

int color_printk(unsigned int FRColor, unsigned int BKcolor, const char *fmt, ...)
{
    int length = 0;
    int i = 0;
    int tab = 0; //牵扯到换行符

    va_list args;        //可变参数
    va_start(args, fmt); //获取可变参数

    length = vsprintf(tempBuf, fmt, args);

    va_end(args);

    for (i = 0; i < length || tab; ++i)
    {
        unsigned char character = (unsigned char)*(tempBuf + i);

        if (character == '\n') //换行
        {
            //行数加1 列数置零
            Pos.YPosition++;
            Pos.XPosition = 0;
        }
        else if (character == '\b') //退格
        {
            Pos.XPosition--;
            //小于0要回到上一行
            if (Pos.XPosition < 0)
            {
                Pos.XPosition = (Pos.XResolution / Pos.XCharSize - 1) * Pos.XCharSize;
                Pos.YPosition--;
                if (Pos.YPosition < 0)
                {
                    Pos.YPosition = (Pos.YResolution / Pos.YCharSize - 1) * Pos.YCharSize;
                }
            }
            putchar(Pos.FB_addr, Pos.XResolution, Pos.XPosition * Pos.XCharSize, Pos.YPosition * Pos.YCharSize, FRColor, BKcolor, ' ');
        }
        else if (character == '\t') //制表
        {
            tab = ((Pos.XPosition + 8) & ~(8 - 1)) - Pos.XPosition;

            while (tab > 0)
            {
                tab--;
                putchar(Pos.FB_addr, Pos.XResolution, Pos.XPosition * Pos.XCharSize, Pos.YPosition * Pos.YCharSize, FRColor, BKcolor, ' ');
                Pos.XPosition++;
                wrap();
            }
        }
        else
        { //普通字符
            putchar(Pos.FB_addr, Pos.XResolution, Pos.XPosition * Pos.XCharSize, Pos.YPosition * Pos.YCharSize, FRColor, BKcolor, (unsigned char)*(tempBuf + i));
            Pos.XPosition++;
        }

        wrap();
    }

    return length;
}

void wrap()
{
    //检测是否需要换行
    if (Pos.XPosition >= (Pos.XResolution / Pos.XCharSize))
    {
        Pos.YPosition++;
        Pos.XPosition = 0;
    }

    if (Pos.YPosition >= (Pos.YResolution / Pos.YCharSize))
    {
        Pos.YPosition = 0;
    }
}
