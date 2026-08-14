import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PromocodeService } from '../src/services/promocode';

vi.mock('../src/services/weather', () => ({
  getWeather: vi.fn(async () => ({
    weather: [{ main: 'Clear', description: 'clear' }],
    main: { temp: 20 },
  })),
}));

describe('PromocodeService', () => {
  let service: PromocodeService;

  beforeEach(() => {
    service = new PromocodeService();
  });

  it('accepts when restrictions are satisfied', async () => {
    service.createPromocode({
      name: 'SummerDeal',
      advantage: { percent: 10 },
      restrictions: [
        { date: { after: '2020-01-01', before: '2030-01-01' } },
        { age: { gt: 18 } },
      ],
    });

    const res = await service.validatePromocode({
      promocode_name: 'SummerDeal',
      arguments: { age: 25, town: 'Lyon' },
    });

    expect(res.status).toBe('accepted');
    expect(res.advantage).toEqual({ percent: 10 });
  });

  it('denies when a restriction fails', async () => {
    service.createPromocode({
      name: 'FutureOnly',
      advantage: { percent: 15 },
      restrictions: [{ date: { after: '2030-01-01' } }, { age: { eq: 99 } }],
    });

    const res = await service.validatePromocode({
      promocode_name: 'FutureOnly',
      arguments: { age: 25 },
    });

    expect(res.status).toBe('denied');
    expect(res.reasons).toEqual(['date restriction not satisfied']);
    expect(res.advantage).toEqual({ percent: 15 });
  });

  it('validates weather restrictions', async () => {
    service.createPromocode({
      name: 'Sunny',
      advantage: { percent: 5 },
      restrictions: [{ weather: { is: 'clear', temp: { gt: 15 } } }],
    });

    const res = await service.validatePromocode({
      promocode_name: 'Sunny',
      arguments: { town: 'Lyon' },
    });

    expect(res.status).toBe('accepted');
  });

  it('accepts an or when a later branch passes', async () => {
    service.createPromocode({
      name: 'OrDeal',
      advantage: { percent: 20 },
      restrictions: [
        {
          or: [{ age: { eq: 40 } }, { age: { lt: 30 } }],
        },
      ],
    });

    const res = await service.validatePromocode({
      promocode_name: 'OrDeal',
      arguments: { age: 25 },
    });

    expect(res.status).toBe('accepted');
    expect(res.reasons).toBeUndefined();
  });

  it('denies an or when every branch fails', async () => {
    service.createPromocode({
      name: 'OrMiss',
      advantage: { percent: 20 },
      restrictions: [
        {
          or: [{ age: { eq: 40 } }, { age: { lt: 18 } }],
        },
      ],
    });

    const res = await service.validatePromocode({
      promocode_name: 'OrMiss',
      arguments: { age: 25 },
    });

    expect(res.status).toBe('denied');
    expect(res.reasons).toEqual(['or restriction not satisfied']);
  });

  it('validates age equality', async () => {
    service.createPromocode({
      name: 'AgeOnly',
      advantage: { percent: 10 },
      restrictions: [{ age: { eq: 30 } }],
    });

    const ok = await service.validatePromocode({
      promocode_name: 'AgeOnly',
      arguments: { age: 30 },
    });
    expect(ok.status).toBe('accepted');

    const ko = await service.validatePromocode({
      promocode_name: 'AgeOnly',
      arguments: { age: 20 },
    });
    expect(ko.status).toBe('denied');
  });

  it('validates age greater than', async () => {
    service.createPromocode({
      name: 'AdultsOnly',
      advantage: { percent: 10 },
      restrictions: [{ age: { gt: 0 } }],
    });

    const res = await service.validatePromocode({
      promocode_name: 'AdultsOnly',
      arguments: { age: 0 },
    });

    expect(res.status).toBe('accepted');
  });

  it('validates temperature greater than', async () => {
    const { getWeather } = await import('../src/services/weather');
    vi.mocked(getWeather).mockResolvedValueOnce({
      weather: [{ main: 'Clear', description: 'clear' }],
      main: { temp: -5 },
    });

    service.createPromocode({
      name: 'AboveZero',
      advantage: { percent: 5 },
      restrictions: [{ weather: { temp: { gt: 0 } } }],
    });

    const res = await service.validatePromocode({
      promocode_name: 'AboveZero',
      arguments: { town: 'Lyon' },
    });

    expect(res.status).toBe('accepted');
  });
});
