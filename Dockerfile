# Build stage
FROM nginx:alpine

# Copy static files
COPY index.html /usr/share/nginx/html/
COPY tech-services.html /usr/share/nginx/html/
COPY favicon.svg /usr/share/nginx/html/
COPY favicon.ico /usr/share/nginx/html/ 2>/dev/null || true

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
