#!/bin/bash
# Contrôle de la charte : aucun écran ne doit écrire de couleur, de taille de police,
# d'espacement ou de rayon en dur. Tout passe par les tokens de Design/System.
cd "$(dirname "$0")/.."
status=0

check() {
  local label="$1" pattern="$2"; shift 2
  local hits
  hits=$(grep -rnE "$pattern" "$@" --include='*.swift' || true)
  if [ -n "$hits" ]; then
    echo "ERREUR : $label"
    echo "$hits" | sed 's/^/    /'
    status=1
  fi
}

SCREENS="Views App"
check "couleur écrite en dur (utiliser DSColor)" 'Color\(hex|Color\(red|UIColor\(' $SCREENS
check "couleur système utilisée directement (utiliser DSColor)" '\.(foregroundStyle|foregroundColor|background|fill|tint|stroke)\(\.(red|green|blue|orange|gray|black|white|yellow|pink|purple)\b|Color\.(red|green|blue|orange|gray|black|white|yellow|pink|purple)\b' $SCREENS
check "ancien thème supprimé (utiliser DSColor, DSFont, DSSpace)" 'Theme\.' $SCREENS Design
check "police écrite en dur (utiliser .ds(...) ou DSFont)" '\.font\(\.' $SCREENS
check "espacement écrit en dur (utiliser DSSpace)" 'spacing: ([1-9]|[0-9]{2,})|\.padding\([^)]*[0-9]' $SCREENS
check "rayon écrit en dur (utiliser DSRadius)" 'cornerRadius: [0-9]' $SCREENS

dups=$(find App Design Domain Persistence Store Views -name '*.swift' -printf '%f\n' | sort | uniq -d)
if [ -n "$dups" ]; then
  echo "ERREUR : noms de fichiers Swift en double (interdit dans un même module) :"
  echo "$dups" | sed 's/^/    /'
  status=1
fi

if [ $status -eq 0 ]; then
  echo "Charte respectée : aucune valeur en dur dans les écrans, aucun nom de fichier en double."
fi
exit $status
