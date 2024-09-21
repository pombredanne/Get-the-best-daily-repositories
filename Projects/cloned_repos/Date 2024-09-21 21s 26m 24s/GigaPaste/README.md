# GigaPaste
File sharing, url shortener and pastebin all in one place.

|![](https://github.com/user-attachments/assets/d75999e5-736a-4ef4-80e8-c9a77079ed45) | ![](https://github.com/user-attachments/assets/34997223-8a08-4707-8490-9c9941f59141) |
|--------------------------------|--------------------------------|
| ![](https://github.com/user-attachments/assets/6a871974-ace4-4482-ab9c-7958f2cc51f7) | ![image](https://github.com/user-attachments/assets/a54146fb-9c5f-46f2-a79b-c338e9272b53) |


# Why it's better than other similar apps :zap:
- works in mobile browsers, can upload file / text with ctrl+v, drag and drop, browse file or through terminal
- Extremely easy to set up, all you need is `go build .` or use the docker-compose.yaml and it's done
- Very easy for modificiations, don't like the style? pick a .css file from [here](https://github.com/dbohdan/classless-css) and replace the `static/theme.css`, don't like the layout? the html page is well commented and structured
- Can run on any OS or deployment platforms like repl.it, render, fly.io, etc
- Designed to run efficiently on any system, regardless of its CPU or memory resources
- Can handle gigabytes of file upload and download with fixed memory and cpu usage
- Encryption done right, all your data can be secured with AES & pbkdf2 for passwords
- Decryption is done on the fly, the encrypted data is never decrypted to the disk
- Short & unambiguous URL generation (with letters like ilI1 omitted) with collision detection
- QR code support to quickly share files to / between mobile devices

# URL shortener 🔗
simply paste any valid url (must start with `http://` or `https://`) to the textbox and upload

# Dont like how it looks? 🎨
pick a .css file from [here](https://github.com/dbohdan/classless-css) and replace the `static/theme.css`, or search for "classless css"

# How to build with docker :whale2:
1. Download / clone this repo
2. Make a folder called `uploads`
3. Run `docker compose up`
   
# How to build without docker 📟
1. Download / clone this repo
2. Open terminal
3. Type `export CGO_ENABLED=1` (linux) or `SET CGO_ENABLED=1` (windows)
4. `go build .`

# Settings ⚙️
You can modify the variables inside `data/settings.json`
- `fileSizeLimitMB` = limit file size (in megabytes)
- `textSizeLimitMB` = limit text size (in megabytes)
- `streamSizeLimitKB` = limit file encryption, decryption, upload & download buffer stream size (in kb) to limit memory usage
- `streamThrottleMS` = add throttle to the encryption, decryption, upload & download buffer to limit cpu usage
- `pbkdf2Iterations` = key derivation algorithm iteration, the higher the better, but 100000 should be enough
- `cmdUploadDefaultDurationMinute` = default file duration if you upload file through curl if duration is not specified

You can modify CPU/memory usage by calculating the memory usage / sec with `streamSizeLimitKB * (1000/streamThrottleMS)`, the default setting can handle 40 MB of data on file upload, download, encryption & decryption / second, you can tune this down if needed

# Curl upload ⬆️
`curl -F "file=@main.go" -F "duration=10" -F "pass=123" -F "burn=true" yoursite.com`
Note that the duration, password, and burn is totally optional, you can just write `curl -F "file=@file.txt" yoursite.com` for quick upload

# Security 🔒
For maximum security, it is recommended to encrypt your file before uploading

# Donate 🤝
BTC Network: bc1qpcx3r7pa0uyc957lt84duqexqmvupceyzvyxh6
