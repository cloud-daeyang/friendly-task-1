FROM golang:1.21

WORKDIR /app

COPY . ./

RUN go build -o event .

EXPOSE 8080

CMD ["./event"]