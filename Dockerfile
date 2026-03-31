# Stage 1: build Flutter web
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL:-https://regulit-api.onrender.com}

# Stage 2: serve with nginx
FROM nginx:alpine

COPY --from=builder /app/build/web /usr/share/nginx/html

# SPA routing — redirect all 404s back to index.html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
