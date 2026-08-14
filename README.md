# Module Promocode — audit / rapport d'étonnement

Tu viens d'arriver chez **Indy**, et tu rejoins une squad qui reprend une feature de code promo pour l'app. La feature a eu une traction il y a quelques années, puis a été mise de côté. Elle est de nouveau intéressante pour Indy, et on souhaite la faire évoluer.

L'équipe a besoin d'un regard neuf sur ce module legacy `Promocode` qu'elle voudrait refondre / améliorer pour le prochain cycle de build.

Dans ce cadre, on te demande de réaliser un **audit / rapport d'étonnement** de ce module dans le but de **rendre ce module extensible**.

## Évaluation

L'objectif de cet exercice est de rendre un rapport d'étonnement, qui servira de base de discussion lors de l'entretien de debrief avec l'équipe.

Nous sommes ouverts à l'utilisation de l'IA pour ce test. Si c'est le cas, merci de joindre au rapport l'export de la conversation associée.

Dans ton rapport d'étonnement, tu dois décrire :

- Comprendre comment le code est implémenté et expliquer ce que tu en as compris
- Relever des erreurs ou non-sens si tu en vois
- Challenger l'existant, et proposer des potentielles améliorations / optimisations
- Tout ce qui te semble intéressant à relever (choix des technos, archi, etc.)

Préparer cet audit devrait te prendre **moins d'une heure**.

### Conseils pratiques

Concentre-toi sur :

- Le fonctionnement de l'algorithme
- La lisibilité et la clarté du code
- L'architecture de l'application
- L'appel à l'API pour récupérer la météo
- Les tests automatisés

## Getting started

```bash
npm install
# variables d'environnement attendues : voir .env.example
OPENWEATHER_API_KEY=ta_clé_openweathermap npm run start:dev
```

Les tests :

```bash
npm test
```

Bonne lecture.
