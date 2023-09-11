package main

import (
    "fmt"
    "net/http"
    "io/ioutil"
)

func eventHandler(w http.ResponseWriter, r *http.Request) {

    response, err := http.Get("https://raw.githubusercontent.com/cloud-skills/study/main/July_2023/day6/promotion_code.txt")
    if err != nil {
        http.Error(w, "Failed to fetch data", http.StatusInternalServerError)
        return
    }
    defer response.Body.Close()

    data, err := ioutil.ReadAll(response.Body)
    if err != nil {
        http.Error(w, "Failed to read data", http.StatusInternalServerError)
        return
    }

    text := string(data)

    fmt.Fprintf(w, "%s", text)
}

func main() {
    http.HandleFunc("/event", eventHandler)
    http.ListenAndServe(":8080", nil)
}