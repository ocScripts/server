package main

import (
	"fmt"
	"hash/crc32"
	"io/ioutil"
	"os"

	"github.com/Trey2k/ocSocket"
)

type newFileData struct {
	Name    string
	Content string
}

func (server *sServer) registerFiles() error {
	files, err := ioutil.ReadDir("luasrc/")
	if err != nil {
		return err
	}

	for _, item := range files {
		if item.IsDir() {
			continue
		}
		file, err := os.OpenFile("luasrc/"+item.Name(), os.O_CREATE, 0644)
		if err != nil {
			return err
		}

		content, err := ioutil.ReadAll(file)
		if err != nil {
			return err
		}

		h := crc32.New(crc32.MakeTable(crc32.IEEE))
		_, err = h.Write(content)
		if err != nil {
			return err
		}

		server.Files[item.Name()] = h.Sum32()
	}

	return nil
}

func (server *sServer) checkFiles(client *ocSocket.Client, files map[string]uint32) error {

	newFiles := false
	for fileName, hash := range files {
		serverHash, ok := server.Files[fileName]
		if ok && serverHash != hash {
			fmt.Println(fileName)
			file, err := os.OpenFile("luasrc/"+fileName, os.O_CREATE, 0644)
			if err != nil {
				return err
			}

			content, err := ioutil.ReadAll(file)
			if err != nil {
				return err
			}

			file.Close()
			data := &newFileData{
				Name:    fileName,
				Content: string(content),
			}
			event, err := ocSocket.NewEvent("newFile", data)
			if err != nil {
				return err
			}

			err = client.SendEvent(event)
			if err != nil {
				return err
			}
			newFiles = true
		}
	}

	if newFiles {
		event, err := ocSocket.NewEvent("reboot", nil)
		if err != nil {
			return err
		}

		err = client.SendEvent(event)
		if err != nil {
			return err
		}
		client.Close()
	}

	return nil
}
