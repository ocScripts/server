package main

import (
	"time"

	"github.com/ocScripts/ocSocket"
)

type MessageEvent struct {
	Message string
}

type sServer struct {
	ClientInfo map[string]sClientInfo //Map of clients and their associated data
	Socket     *ocSocket.OCSocket     //Socket connection object
	Files      map[string]uint32      //file names (NOT paths!) and crc32 hashes
}

type sClientInfo struct {
	Type       string            //Client type string (robot, cnc, display, etc)
	Files      map[string]uint32 //Current client files and crc32 hashes
	Components []string          //Array of opencomputers components currently installed
}

//newServer returns a new, populated sServer struct
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

//clientCheckup
func (server *sServer) clientCheckup() {
	ticker := time.NewTicker(time.Second)

	for {
		<-ticker.C

		for uuid := range server.ClientInfo {
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

	server.Socket = ocSocket.NewSocket(":56552")
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
