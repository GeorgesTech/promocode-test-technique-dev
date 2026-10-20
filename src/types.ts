export type Advantage = {
  percent: number;
};

export type Restriction = {
  age?: { eq?: number; lt?: number; gt?: number };
  date?: { after?: string; before?: string };
  weather?: { is?: string; temp?: { eq?: number; lt?: number; gt?: number } };
  or?: Restriction[];
  and?: Restriction[];
};

export type Promocode = {
  name: string;
  advantage: Advantage;
  restrictions: Restriction[];
};

export type ValidationArgs = {
  age?: number;
  town?: string;
};

export type ValidationResult = {
  promocode_name: string;
  status: 'accepted' | 'denied';
  advantage?: Advantage;
  reasons?: string[];
};
