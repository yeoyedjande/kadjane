# --- Construction -----------------------------------------------------------
FROM node:22-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

# --- Service statique -------------------------------------------------------
FROM nginx:1.27-alpine

COPY --from=build /app/dist/admin/browser /usr/share/nginx/html

# Déposé comme modèle : l'entrypoint officiel de l'image applique `envsubst`
# sur `/etc/nginx/templates/*.template` avant de démarrer nginx.
COPY nginx.conf /etc/nginx/templates/default.conf.template

# Le filtre restreint la substitution à `PORT`. Sans lui, `envsubst` viderait
# aussi les variables de nginx (`$uri`…), qui ne sont pas des variables
# d'environnement.
ENV NGINX_ENVSUBST_FILTER=^PORT$ \
    PORT=8080

EXPOSE 8080
