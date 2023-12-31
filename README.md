# AXI4🎉✨
A AXI4 project of Verilog.

## 工程简介
这个工程已经写完很久了，本质是一个AXI4的DMA工程文件（主机）。
使用这个工程可以直接调用顶层和DDR的MIG核来进行DDR的读写操作。

### 实现功能
本工程可以实现对DDR的突发读和突发写。

### 资源占用
![image](https://github.com/Vikkdsun/AXI4/assets/114153159/7f7ea02f-9d76-43b1-b3d1-ead1d97d8c7e)

## 详解
### 突发写
AXI4总线读写是独立的、分离的、无耦合的。
本工程实现的逻辑是接收到用户端的写数据valid和数据，进行移位组成AXI发送数据的长度后发送到Buffer（文件中没有独立的Buffer模块，是在Master文件内部），这个Buffer是用FIFO组成的。
但是如果传输的数据个数达不到设置的突发长度的话，是不会从Buffer中读出数据写进从机的。

### 突发读
读通道要考虑很多握手。
首先收到用户的读请求，于是收集要发送的读的指令，这段时间是不允许用户发出请求的，会发出Busy信号。
因为读请求可以请求很多次，所以这里也有一个Buffer（文件中没有独立的Buffer模块，是在Master文件内部），如果这个Buffer内的指令太多了，那么也不会接收请求。
其次，什么时候从Buffer内读出指令也很重要，因为读出来的数据要存在另一个Buffer中（数据Buffer），所以要查看数据Buffer内是否有足够的空间，不然也不会从Buffer读指令。
最后，读到的数据先存在数据Buffer，读出来数据后要做移位恢复用户数据长度，所以这里读使能是离散的，这也证明了，一般读出数据写进数据Buffer要快于读。
