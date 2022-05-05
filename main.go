package main

import (
	"time"

	"github.com/ocScripts/ocSocket"
)

type MessageEvent struct {
	Message string
}

type sClientInfo struct {
	Type      string
	Files     map[string]uint32
	Componets []string
}

type sServer struct {
	ClientInfo map[string]sClientInfo
	Socket     *ocSocket.OCSocket
	Files      map[string]uint32
}

func newServer() *sServer {
	toReturn := &sServer{}
	toReturn.ClientInfo = make(map[string]sClientInfo)
	toReturn.Files = make(map[string]uint32)

	err := toReturn.registerFiles()
	if err != nil {
		panic(err)
	}
	go toReturn.clientCheckup()
	return toReturn
}

func (server *sServer) clientCheckup() {
	for _ = range time.Tick(time.Second) {
		for uuid, _ := range server.ClientInfo {
			event, err := ocSocket.NewEvent("test", &MessageEvent{Message: "Hello there"})
			if err != nil {
				panic(err)
			}
			server.Socket.SendClientEvent(uuid, event)
		}
	}
}

func main() {
	server := newServer()
	server.Socket = ocSocket.NewSocket(":42069")
	go server.Socket.Open()
	for {
		event := <-server.Socket.EventChan
		switch event.Name {
		case "register":
			err := server.registerHandler(event)
			if err != nil {
				panic(err)
			}
		}
	}
}
