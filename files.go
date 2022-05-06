package main

import (
	"encoding/json"
	"fmt"
	"hash/crc32"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"

	"github.com/fsnotify/fsnotify"
	"github.com/ocScripts/ocSocket"
)

type newFileData struct {
	Name    string
	Content string
}

type errorData struct {
	Err string
}

func (server *sServer) registerFiles() error {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		return err
	}

	files, err := ioutil.ReadDir("./luasrc")
	if err != nil {
		return err
	}

	for _, item := range files {
		if item.IsDir() {
			continue
		}

		err = server.updateFileRegister(filepath.Join("./luasrc", item.Name()))
		if err != nil {
			return err
		}

		err = watcher.Add(filepath.Join("./luasrc", item.Name()))
		if err != nil {
			return err
		}
	}

	go func() {
		for {
			select {
			case event, ok := <-watcher.Events:
				if !ok {
					watcher.Close()

					return
				}

				if event.Op&fsnotify.Write == fsnotify.Write {
					err = server.updateFileRegister(event.Name)
					if err != nil {
						return
					}
				}
			case _, ok := <-watcher.Errors:
				if !ok {
					watcher.Close()

					return
				}
			}
		}
	}()

	return nil
}

func (server *sServer) updateFileRegister(filePath string) (err error) {
	file, err := os.OpenFile(filepath.Join(filePath), os.O_CREATE, 0644)
	if err != nil {
		return err
	}
	defer file.Close()

	content, err := ioutil.ReadAll(file)
	if err != nil {
		return err
	}

	hash := crc32.New(crc32.MakeTable(crc32.IEEE))
	_, err = hash.Write(content)
	if err != nil {
		return err
	}

	server.Files[filepath.Base(filePath)] = hash.Sum32()

	return nil
}

func (server *sServer) checkFiles(client *ocSocket.Client, files map[string]uint32) error {
	newFiles := false
	for fileName, hash := range files {
		serverHash, ok := server.Files[fileName]
		if ok && serverHash != hash {
			newFiles = true
			fmt.Println(fileName)
			file, err := os.OpenFile("luasrc/"+fileName, os.O_CREATE, 0644)
			if err != nil {
				return err
			}
			defer file.Close()

			content, err := ioutil.ReadAll(file)
			if err != nil {
				return err
			}

			data := &newFileData{
				Name:    fileName,
				Content: string(content),
			}

			// Wait until the file is written
			holdChan := make(chan bool)

			client.TriggerClientCallback("newFile", data, func(data string) {
				errData := &errorData{}
				err := json.Unmarshal([]byte(data), errData)
				if err != nil {
					panic(err)
				}
				if errData.Err != "" {
					log.Printf("Client '%s' ran into error '%s' while makeing file '%s'", client.UUID, errData.Err, fileName)
				}
				holdChan <- true

			})

			<-holdChan
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
