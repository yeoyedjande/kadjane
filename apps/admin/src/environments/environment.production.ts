/**
 * Production : backend déployé sur Railway.
 *
 * L'URL est absolue, car le back-office et l'API ne partagent pas la même
 * origine — le chemin relatif `/api/v1` ne fonctionnerait que derrière un
 * reverse proxy commun. L'origine du back-office doit donc figurer dans
 * `CORS_ORIGINS` côté backend.
 *
 * À remplacer par `https://api.kadjane.app` le jour où le domaine existe.
 */
const API_ORIGIN = 'https://kadjane.up.railway.app';

export const environment = {
  production: true,
  apiBaseUrl: `${API_ORIGIN}/api/v1`,
  filesBaseUrl: API_ORIGIN,
  appName: 'Kadjane Admin',
};
