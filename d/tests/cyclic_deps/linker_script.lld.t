SECTIONS
{
    __minfo : {
        *(EXCLUDE_FILE(*b.o) __minfo)
        /*
        Because of how D runtime works, modules in the cycle will be
        initialized in the reverse order of their appearance in the
        __minfo section. So but putting b.o last, we ensure that
        shared constructors from b will be called before those from a.
        */
        *b.o(__minfo)
    }
} INSERT AFTER .rodata;
