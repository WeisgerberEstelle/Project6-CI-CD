FROM node:20.19 AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:1.27
COPY --from=build /app/dist/olympic-games-starter/browser /app
COPY nginx/nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
