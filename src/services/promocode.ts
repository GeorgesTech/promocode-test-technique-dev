import {
  Promocode,
  Restriction,
  ValidationArgs,
  ValidationResult,
} from '../types';
import { getWeather } from './weather';

export class PromocodeService {
  private promocodes: Promocode[];

  constructor() {
    this.promocodes = [];
  }

  listPromocodes(): Promocode[] {
    return this.promocodes;
  }

  createPromocode(payload: Promocode): Promocode {
    this.promocodes.push(payload);
    return payload;
  }

  getPromocode(name: string): Promocode {
    const found = this.promocodes.find((p) => p.name === name);
    if (!found) {
      const error: any = new Error('promocode not found');
      error.statusCode = 404;
      throw error;
    }
    return found;
  }

  async validatePromocode(payload: {
    promocode_name: string;
    arguments: ValidationArgs;
  }): Promise<ValidationResult> {
    const promocode = this.getPromocode(payload.promocode_name);
    const args = payload.arguments || {};
    const reasons: string[] = [];

    for (const restriction of promocode.restrictions || []) {
      const ok = await this.testRestriction(restriction, args, reasons);
      if (!ok) {
        break;
      }
    }

    if (reasons.length === 0) {
      return {
        promocode_name: promocode.name,
        status: 'accepted',
        advantage: promocode.advantage,
      };
    }

    return {
      promocode_name: promocode.name,
      status: 'denied',
      advantage: promocode.advantage,
      reasons,
    };
  }

  async testRestriction(
    restriction: Restriction,
    args: ValidationArgs,
    reasons: string[],
  ): Promise<boolean> {
    const types = Object.keys(restriction);
    if (types.length !== 1) {
      reasons.push('invalid restriction: expected exactly one rule');
      return false;
    }

    const type = types[0];
    const rule = (restriction as any)[type];

    if (type === 'or') {
      for (const child of rule) {
        const local: string[] = [];
        const ok = await this.testRestriction(child, args, local);
        if (ok) return true;
      }
      reasons.push('or restriction not satisfied');
      return false;
    }

    if (type === 'and') {
      for (const child of rule) {
        const ok = await this.testRestriction(child, args, reasons);
        if (!ok) return false;
      }
      return true;
    }

    if (type === 'age') {
      if (rule.eq && args.age !== rule.eq) {
        reasons.push('age restriction not satisfied');
        return false;
      }
      if (rule.lt && args.age >= rule.lt) {
        reasons.push('age restriction not satisfied');
        return false;
      }
      if (rule.gt && args.age <= rule.gt) {
        reasons.push('age restriction not satisfied');
        return false;
      }
      return true;
    }

    if (type === 'date') {
      const today = new Date();
      if (rule.after && today <= new Date(rule.after)) {
        reasons.push('date restriction not satisfied');
        return false;
      }
      if (rule.before && today >= new Date(rule.before)) {
        reasons.push('date restriction not satisfied');
        return false;
      }
      return true;
    }

    if (type === 'weather') {
      try {
        const weather = await getWeather(args.town);
        const condition = weather.weather[0].description.toLowerCase();
        const temp = weather.main.temp;

        if (rule.is && condition !== rule.is.toLowerCase()) {
          reasons.push('weather is not ' + rule.is);
          return false;
        }

        if (rule.temp) {
          if (rule.temp.eq && temp !== rule.temp.eq) {
            reasons.push('temperature does not match');
            return false;
          }
          if (rule.temp.lt && temp >= rule.temp.lt) {
            reasons.push('temperature too high');
            return false;
          }
          if (rule.temp.gt && temp <= rule.temp.gt) {
            reasons.push('temperature too low');
            return false;
          }
        }

        return true;
      } catch (e) {
        reasons.push('weather service unavailable');
        return false;
      }
    }

    reasons.push('unknown restriction: ' + type);
    return false;
  }
}
