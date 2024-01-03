package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
)

const (
	defaultPort = "8080"
)

type Response struct {
	Color string `json:"color"`
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = defaultPort
	}
	log.Printf("Will listen on port %s", port)

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		colors := []string{"blue", "red", "green", "magenta", "orange"}

		response := Response{
			Color: colors[rand.Intn(len(colors))],
		}

		marshaled, err := json.Marshal(response)
		if err != nil {
			log.Fatal(err)
		}

		w.Header().Set("Content-Type", "application/json")
		w.Write(marshaled)
	})

	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%s", port), nil))
}
