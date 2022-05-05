package main

import (
	"github.com/ocScripts/ocSocket"
)

type RegisterInfo struct {
	Files     map[string]uint32
	Type      string
	Componets []string
}

func (server *sServer) registerHandler(event *ocSocket.Event) error {
	data := &RegisterInfo{}
	client := event.Client

	err := event.ParseData(data)
	if err != nil {
		return err
	}

	server.ClientInfo[client.UUID] = sClientInfo{
		Files:     data.Files,
		Type:      data.Type,
		Componets: data.Componets,
	}

	return server.checkFiles(event.Client, data.Files)
}
