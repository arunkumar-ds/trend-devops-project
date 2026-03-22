# Use Nginx to serve the pre-built React app
FROM nginx:stable-alpine

# Copy the build output (dist folder) to Nginx's html directory
COPY dist/ /usr/share/nginx/html

# Update Nginx to listen on Port 3000 as per project requirements
RUN sed -i 's/listen       80;/listen       3000;/g' /etc/nginx/conf.d/default.conf

EXPOSE 3000

CMD ["nginx", "-g", "daemon off;"]
