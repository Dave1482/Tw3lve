
#import "kernel_utils.h"
#import "patchfinder64.h"
#import "offsetof.h"
#import "OffsetHolder.h"
#import "kexecute.h"
#import "utils.h"

#include "find_port.h"

#include "VarHolder.h"

static mach_port_t tfpOwO = MACH_PORT_NULL;

void setOwO(mach_port_t OwO2Set)
{
    tfpOwO = OwO2Set;
    NSLog(@"%@", [NSString stringWithFormat:@"TFP0: %x", tfpOwO]);
}

uint64_t Kernel_alloc(vm_size_t size) {
    mach_vm_address_t address = 0;
    mach_vm_allocate(tfpOwO, (mach_vm_address_t *)&address, size, VM_FLAGS_ANYWHERE);
    return address;
}

void Kernel_free(mach_vm_address_t address, vm_size_t size) {
    mach_vm_deallocate(tfpOwO, address, size);
}

int Kernel_strcmp(uint64_t kstr, const char* str) {
    // XXX be safer, dont just assume you wont cause any
    // page faults by this
    size_t len = strlen(str) + 1;
    char *local = malloc(len + 1);
    local[len] = '\0';
    
    int ret = 1;
    
    if (KernelRead(kstr, local, len) == len) {
        ret = strcmp(local, str);
    }
    
    free(local);
    
    return ret;
}

uint64_t TaskSelfAddr() {
    
    return find_port_address(mach_task_self(), MACH_MSG_TYPE_COPY_SEND);
}

uint64_t IPCSpaceKernel() {
    return KernelRead_64bits(TaskSelfAddr() + 0x60);
}

uint64_t FindPortAddress(mach_port_name_t port) {
   
    uint64_t task_port_addr = TaskSelfAddr();
    //uint64_t task_addr = TaskSelfAddr();
    uint64_t task_addr = KernelRead_64bits(task_port_addr + off_ip_kobject);
    uint64_t itk_space = KernelRead_64bits(task_addr + off_itk_space);
    
    uint64_t is_table = KernelRead_64bits(itk_space + off_ipc_space_is_table);
    
    uint32_t port_index = port >> 8;
    const int sizeof_ipc_entry_t = 0x18;

    uint64_t port_addr = KernelRead_64bits(is_table + (port_index * sizeof_ipc_entry_t));

    return port_addr;
}

mach_port_t FakeHostPriv_port = MACH_PORT_NULL;

// build a fake host priv port
mach_port_t FakeHostPriv() {
    if (FakeHostPriv_port != MACH_PORT_NULL) {
        return FakeHostPriv_port;
    }
    // get the address of realhost:
    uint64_t hostport_addr = FindPortAddress(mach_host_self());
    uint64_t realhost = KernelRead_64bits(hostport_addr + off_ip_kobject);
    
    // allocate a port
    mach_port_t port = MACH_PORT_NULL;
    kern_return_t err;
    err = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port);
    if (err != KERN_SUCCESS) {
        printf("[-] failed to allocate port\n");
        return MACH_PORT_NULL;
    }
    // get a send right
    mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND);
    
    // make sure port type has IKOT_HOST_PRIV
    PatchHostPriv(port);
    
    // locate the port
    uint64_t port_addr = FindPortAddress(port);

    // change the space of the port
    KernelWrite_64bits(port_addr + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_RECEIVER), IPCSpaceKernel());
    
    // set the kobject
    KernelWrite_64bits(port_addr + off_ip_kobject, realhost);
    
    FakeHostPriv_port = port;
    
    return port;
}

uint64_t Kernel_alloc_wired(uint64_t size) {
    if (tfpOwO == MACH_PORT_NULL) {
        printf("[-] attempt to allocate kernel memory before any kernel memory write primitives available\n");
        sleep(3);
        return 0;
    }
    
    kern_return_t err;
    mach_vm_address_t addr = 0;
    mach_vm_size_t ksize = round_page_kernel(size);
    
    printf("[*] vm_kernel_page_size: %lx\n", vm_kernel_page_size);
    
    err = mach_vm_allocate(tfpOwO, &addr, ksize+0x4000, VM_FLAGS_ANYWHERE);
    if (err != KERN_SUCCESS) {
        printf("[-] unable to allocate kernel memory via tfp0: %s %x\n", mach_error_string(err), err);
        sleep(3);
        return 0;
    }
    
    printf("[+] allocated address: %llx\n", addr);
    
    addr += 0x3fff;
    addr &= ~0x3fffull;
    
    printf("[*] address to wire: %llx\n", addr);
    
    err = mach_vm_wire(FakeHostPriv(), tfpOwO, addr, ksize, VM_PROT_READ|VM_PROT_WRITE);
    if (err != KERN_SUCCESS) {
        printf("[-] unable to wire kernel memory via tfp0: %s %x\n", mach_error_string(err), err);
        sleep(3);
        return 0;
    }
    return addr;
}


size_t KernelRead(uint64_t where, void* p, size_t size)
{
    int rv;
    size_t offset = 0;
    while (offset < size) {
        mach_vm_size_t sz, chunk = 2048;
        if (chunk > size - offset) {
            chunk = size - offset;
        }
        rv = mach_vm_read_overwrite(tfpOwO,
                                    where + offset,
                                    chunk,
                                    (mach_vm_address_t)p + offset,
                                    &sz);
        if (rv || sz == 0) {
            break;
        }
        offset += sz;
    }
    return offset;
}


bool KernelBuffer(uint64_t kaddr, void* buffer, size_t length)
{
    if (!MACH_PORT_VALID(tfpOwO)) {
        NSLog(@"attempt to read kernel memory but no kernel memory read primitives available");
        return 0;
    }
    
    return (KernelRead(kaddr, buffer, length) == length);
}

uint64_t Read64ViaTfp0(uint64_t kaddr)
{
    uint64_t val = 0;
    KernelBuffer(kaddr, &val, sizeof(val));
    return val;
}

uint32_t Read32ViaTfp0(uint64_t kaddr)
{
    uint32_t val = 0;
    KernelBuffer(kaddr, &val, sizeof(val));
    return val;}

uint32_t KernelRead_32bits(uint64_t where) {
    return Read32ViaTfp0(where);
}

uint64_t KernelRead_64bits(uint64_t where) {
    return Read64ViaTfp0(where);
}


boolean_t KernelWrite(uint64_t address, const void *data, size_t size) {
    {
        kern_return_t kr = mach_vm_write(tfpOwO, address,
                                         (mach_vm_address_t) data, (mach_msg_size_t) size);
        if (kr != KERN_SUCCESS) {
            NSLog(@"%s returned %d: %s", "mach_vm_write", kr, mach_error_string(kr));
            NSLog(@"could not %s address 0x%016llx", "write", address);
            return false;
        }
        return true;
    }
}

void KernelWrite_32bits(uint64_t kaddr, uint32_t val)
{
    if (tfpOwO == MACH_PORT_NULL) {
        NSLog(@"attempt to write to kernel memory before any kernel memory write primitives available");
        return;
    }
    
    KernelWrite(kaddr, &val, sizeof(val));
}

void KernelWrite_64bits(uint64_t kaddr, uint64_t val)
{
    if (tfpOwO == MACH_PORT_NULL) {
        NSLog(@"attempt to write to kernel memory before any kernel memory write primitives available");
        return;
    }
    
    KernelWrite(kaddr, &val, sizeof(val));
}

const uint64_t kernel_address_space_base = 0xffff000000000000;
void Kernel_memcpy(uint64_t dest, uint64_t src, uint32_t length) {
    if (dest >= kernel_address_space_base) {
        // copy to kernel:
        KernelWrite(dest, (void*) src, length);
    } else {
        // copy from kernel
        KernelRead(src, (void*)dest, length);
    }
}

void convertPortToTaskPort(mach_port_t port, uint64_t space, uint64_t task_kaddr) {
    // now make the changes to the port object to make it a task port:
    uint64_t port_kaddr = FindPortAddress(port);
    
    KernelWrite_32bits(port_kaddr + koffset(KSTRUCT_OFFSET_IPC_PORT_IO_BITS), 0x80000000 | 2);
    KernelWrite_32bits(port_kaddr + koffset(KSTRUCT_OFFSET_IPC_PORT_IO_REFERENCES), 0xf00d);
    KernelWrite_32bits(port_kaddr + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_SRIGHTS), 0xf00d);
    KernelWrite_64bits(port_kaddr + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_RECEIVER), space);
    KernelWrite_64bits(port_kaddr + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT),  task_kaddr);
    
    // swap our receive right for a send right:
    uint64_t task_port_addr = TaskSelfAddr();
    uint64_t task_addr = KernelRead_64bits(task_port_addr + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
    uint64_t itk_space = KernelRead_64bits(task_addr + koffset(KSTRUCT_OFFSET_TASK_ITK_SPACE));
    uint64_t is_table = KernelRead_64bits(itk_space + koffset(KSTRUCT_OFFSET_IPC_SPACE_IS_TABLE));
    
    uint32_t port_index = port >> 8;
    const int sizeof_ipc_entry_t = 0x18;
    uint32_t bits = KernelRead_32bits(is_table + (port_index * sizeof_ipc_entry_t) + 8); // 8 = offset of ie_bits in struct ipc_entry
    
#define IE_BITS_SEND (1<<16)
#define IE_BITS_RECEIVE (1<<17)
    
    bits &= (~IE_BITS_RECEIVE);
    bits |= IE_BITS_SEND;
    
    KernelWrite_32bits(is_table + (port_index * sizeof_ipc_entry_t) + 8, bits);
}

void MakePortFakeTaskPort(mach_port_t port, uint64_t task_kaddr) {
    convertPortToTaskPort(port, IPCSpaceKernel(), task_kaddr);
}

uint64_t proc_of_pid(pid_t pid) {
    uint64_t proc = KernelRead_64bits(find_allproc()), pd;
    while (proc) { //iterate over all processes till we find the one we're looking for
        pd = KernelRead_32bits(proc + koffset(KSTRUCT_OFFSET_PROC_PID));
        if (pd == pid) return proc;
        proc = KernelRead_64bits(proc + koffset(KSTRUCT_OFFSET_PROC_P_LIST));
    }
    
    return 0;
}

uint64_t get_kernel_addr()
{
    static uint64_t kernel_proc_struct_addr = 0;
    static uint64_t kernel_ucred_struct_addr = 0;
    if (kernel_proc_struct_addr == 0) {
        kernel_proc_struct_addr = proc_of_pid(0);
    }
    if (kernel_ucred_struct_addr == 0) {
        kernel_ucred_struct_addr = Read64ViaTfp0(kernel_proc_struct_addr + koffset(KSTRUCT_OFFSET_PROC_UCRED));
    }
    return kernel_ucred_struct_addr;
}





uint64_t proc_of_procName(char *nm) {
    uint64_t proc = KernelRead_64bits(find_allproc());
    char name[40] = {0};
    while (proc) {
        KernelRead(proc + off_p_comm, name, 40); //read 20 bytes off the process's name and compare
        if (strstr(name, nm)) return proc;
        proc = KernelRead_64bits(proc);
    }
    return 0;
}

unsigned int pid_of_procName(char *nm) {
    uint64_t proc = KernelRead_64bits(find_allproc());
    char name[40] = {0};
    while (proc) {
        KernelRead(proc + off_p_comm, name, 40);
        if (strstr(name, nm)) return KernelRead_32bits(proc + off_p_pid);
        proc = KernelRead_64bits(proc);
    }
    return 0;
}

uint64_t taskStruct_of_pid(pid_t pid) {
    //UH OH?
    uint64_t task_kaddr = KernelRead_64bits(TaskSelfAddr() + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
    while (task_kaddr) {
        uint64_t proc = KernelRead_64bits(task_kaddr + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
        uint32_t pd = KernelRead_32bits(proc + off_p_pid);
        if (pd == pid) return task_kaddr;
        task_kaddr = KernelRead_64bits(task_kaddr + koffset(KSTRUCT_OFFSET_TASK_PREV));
    }
    return 0;
}

uint64_t taskStruct_of_procName(char *nm) {
    uint64_t task_kaddr = KernelRead_64bits(TaskSelfAddr() + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
    char name[40] = {0};
    while (task_kaddr) {
        uint64_t proc = KernelRead_64bits(task_kaddr + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
        KernelRead(proc + off_p_comm, name, 40);
        if (strstr(name, nm)) return task_kaddr;
        task_kaddr = KernelRead_64bits(task_kaddr + koffset(KSTRUCT_OFFSET_TASK_PREV));
    }
    return 0;
}

uint64_t taskPortKaddr_of_pid(pid_t pid) {
    uint64_t proc = proc_of_pid(pid);
    if (!proc) {
        printf("[-] Failed to find proc of pid %d\n", pid);
        return 0;
    }
    uint64_t task = KernelRead_64bits(proc + off_task);
    uint64_t itk_space = KernelRead_64bits(task + off_itk_space);
    uint64_t is_table = KernelRead_64bits(itk_space + off_ipc_space_is_table);
    uint64_t task_port_kaddr = KernelRead_64bits(is_table + 0x18);
    return task_port_kaddr;
}

uint64_t taskPortKaddr_of_procName(char *nm) {
    uint64_t proc = proc_of_procName(nm);
    if (!proc) {
        printf("[-] Failed to find proc of process %s\n", nm);
        return 0;
    }
    uint64_t task = KernelRead_64bits(proc + off_task);
    uint64_t itk_space = KernelRead_64bits(task + off_itk_space);
    uint64_t is_table = KernelRead_64bits(itk_space + off_ipc_space_is_table);
    uint64_t task_port_kaddr = KernelRead_64bits(is_table + 0x18);
    return task_port_kaddr;
}

// Original method by Ian Beer
mach_port_t task_for_pid_in_kernel(pid_t pid) {
    
    // allocate a new port we have a send right to
    mach_port_t port = MACH_PORT_NULL;
    mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port);
    mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND);
    
    // find task port in kernel
    uint64_t task_port_kaddr = taskPortKaddr_of_pid(pid);
    uint64_t task = KernelRead_64bits(proc_of_pid(pid) + off_task);
    
    // leak some refs
    KernelWrite_32bits(task_port_kaddr + 0x4, 0x383838);
    KernelWrite_32bits(task + koffset(KSTRUCT_OFFSET_TASK_REF_COUNT), 0x393939);
    
    // get the address of the ipc_port of our allocated port
    uint64_t selfproc = proc_of_pid(getpid());
    if (!selfproc) {
        printf("[-] Failed to find our proc?\n");
        return MACH_PORT_NULL;
    }
    uint64_t selftask = KernelRead_64bits(selfproc + off_task);
    uint64_t itk_space = KernelRead_64bits(selftask + off_itk_space);
    uint64_t is_table = KernelRead_64bits(itk_space + off_ipc_space_is_table);
    uint32_t port_index = port >> 8;
    
    // point the port's ie_object to the task port
    KernelWrite_64bits(is_table + (port_index * 0x18), task_port_kaddr);
    
    // remove our recieve right
    uint32_t ie_bits = KernelRead_32bits(is_table + (port_index * 0x18) + 8);
    ie_bits &= ~(1 << 17); // clear MACH_PORT_TYPE(MACH_PORT_RIGHT_RECIEVE)
    KernelWrite_32bits(is_table + (port_index * 0x18) + 8, ie_bits);
    
    return port;
}

uint64_t ZmFixAddr(uint64_t addr) {
    static kmap_hdr_t zm_hdr = {0, 0, 0, 0};
    
    if (zm_hdr.start == 0) {
        // xxx rk64(0) ?!
        uint64_t zone_map = KernelRead_64bits(find_zone_map_ref());
        // hdr is at offset 0x10, mutexes at start
        size_t r = KernelRead(zone_map + 0x10, &zm_hdr, sizeof(zm_hdr));
        //printf("zm_range: 0x%llx - 0x%llx (read 0x%zx, exp 0x%zx)\n", zm_hdr.start, zm_hdr.end, r, sizeof(zm_hdr));
        
        if (r != sizeof(zm_hdr) || zm_hdr.start == 0 || zm_hdr.end == 0) {
            printf("[-] KernelRead of zone_map failed!\n");
            return 1;
        }
        
        if (zm_hdr.end - zm_hdr.start > 0x100000000) {
            printf("[-] zone_map is too big, sorry.\n");
            return 1;
        }
    }
    
    uint64_t zm_tmp = (zm_hdr.start & 0xffffffff00000000) | ((addr) & 0xffffffff);
    
    return zm_tmp < zm_hdr.start ? zm_tmp + 0x100000000 : zm_tmp;
}



