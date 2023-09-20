FROM node:lts-alpine

WORKDIR /app

COPY . ./

RUN npm i

EXPOSE 8080

CMD ["node", "allow.js"]