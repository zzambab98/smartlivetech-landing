# Build stage
FROM nginx:alpine

# Copy static files
COPY index.html /usr/share/nginx/html/
COPY tech-services.html /usr/share/nginx/html/
COPY favicon.jpg /usr/share/nginx/html/
COPY main.jpg /usr/share/nginx/html/
COPY images/ /usr/share/nginx/html/images/

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
