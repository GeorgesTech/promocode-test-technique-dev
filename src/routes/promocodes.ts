import { FastifyInstance } from 'fastify';
import { PromocodeService } from '../services/promocode';
import { Promocode } from '../types';

export function registerPromocodeRoutes(
  app: FastifyInstance,
  service: PromocodeService,
) {
  app.get('/promocodes', async (_req, reply) => {
    return reply.send(service.listPromocodes());
  });

  app.post('/promocodes', async (req, reply) => {
    const body = req.body as Promocode;
    if (!body || !body.name || !body.advantage) {
      return reply.code(400).send({ error: 'invalid payload' });
    }
    service.createPromocode(body);
    return reply.code(201).send({ name: body.name });
  });

  app.post('/promocodes/validate', async (req, reply) => {
    const body = req.body as any;
    try {
      const result = await service.validatePromocode({
        promocode_name: body.promocode_name,
        arguments: body.arguments || {},
      });
      return reply.code(200).send(result);
    } catch (e: any) {
      return reply.code(e.statusCode || 500).send({ error: e.message });
    }
  });
}
