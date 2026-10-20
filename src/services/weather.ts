export function getWeather(town: string): Promise<any> {
  const apiKey = process.env.OPENWEATHER_API_KEY;
  const url =
    'https://api.openweathermap.org/data/2.5/weather?q=' +
    town +
    '&appid=' +
    apiKey +
    '&units=metric';

  return fetch(url).then((res) => res.json());
}
