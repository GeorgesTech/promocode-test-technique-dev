import Fastify from 'fastify';
import { registerPromocodeRoutes } from './routes/promocodes';
import { PromocodeService } from './services/promocode';

const app = Fastify({ logger: true });
const service = new PromocodeService();

registerPromocodeRoutes(app, service);

const port = parseInt(process.env.PORT || '3000', 10);

app.listen({ port, host: '0.0.0.0' }).catch((err) => {
  console.error(err);
  process.exit(1);
});
