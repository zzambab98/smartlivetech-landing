# Build stage
FROM nginx:alpine

# Copy static files
COPY index.html /usr/share/nginx/html/
COPY tech-services.html /usr/share/nginx/html/
COPY favicon.jpg /usr/share/nginx/html/
COPY main.jpg /usr/share/nginx/html/

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
