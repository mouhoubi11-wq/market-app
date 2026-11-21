import 'package:flutter/material.dart';

import '../config.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  Widget _h(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      );

  Widget _p(String t) =>
      Text(t, style: const TextStyle(fontSize: 14.5, height: 1.5));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Conditions d'utilisation")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _h('1. Objet'),
          _p('Marché est une application de petites annonces entre particuliers. '
              'Marché met en relation des personnes qui veulent acheter ou vendre : '
              'il n\'est ni vendeur, ni acheteur, et n\'intervient dans aucune transaction, '
              'aucun paiement ni aucune livraison.'),
          _h('2. Votre annonce'),
          _p('En publiant une annonce, vous certifiez que : vous avez le droit de vendre ou '
              'd\'acheter ce dont vous parlez, les informations sont exactes, les photos '
              'vous appartiennent et ne montrent pas de personnes identifiables sans leur accord.'),
          _h('3. Contenus interdits'),
          _p('Sont interdits : les armes et munitions, les drogues et substances illicites, '
              'les médicaments sur ordonnance, les contrefaçons, les espèces animales protégées, '
              'les documents officiels, les contenus pornographiques, violents ou haineux, '
              'les annonces trompeuses ou frauduleuses, les données personnelles de tiers, '
              'et plus généralement tout bien ou service interdit par la loi algérienne.'),
          _h('4. Modération'),
          _p('Tout utilisateur peut signaler une annonce. Nous pouvons supprimer, sans préavis, '
              'toute annonce qui ne respecte pas ces conditions, et empêcher son auteur de publier à nouveau.'),
          _h('5. Vos données'),
          _p('Le numéro de téléphone que vous saisissez dans une annonce est visible par tous '
              'les utilisateurs de l\'application. N\'y mettez que ce numéro. '
              'L\'application vous attribue un identifiant anonyme, sans nom ni adresse e-mail. '
              'Vos favoris et la liste des utilisateurs bloqués sont conservés uniquement sur votre téléphone. '
              'Vous pouvez supprimer vos annonces à tout moment depuis l\'onglet « Mes annonces ».'),
          _h('6. Conseils de sécurité'),
          _p('Rencontrez-vous dans un lieu public. Vérifiez l\'article avant de payer. '
              'Ne versez jamais d\'argent à l\'avance à une personne que vous ne connaissez pas. '
              'Méfiez-vous des prix trop beaux pour être vrais.'),
          _h('7. Responsabilité'),
          _p('Les annonces sont publiées sous la seule responsabilité de leurs auteurs. '
              'Marché ne garantit pas leur exactitude et n\'est pas responsable des litiges '
              'entre utilisateurs, ni des pertes ou dommages liés à une transaction.'),
          _h('8. Contact'),
          _p('Pour toute question ou demande de suppression de contenu : $kContactEmail'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
