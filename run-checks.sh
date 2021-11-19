
echo "BOUVIER CONNECTIVITY"
echo "## PATTY"
oc -n bouvier exec -ti deploy/patty-deployment -- ./container-helper check

echo "## SELMA"
oc -n bouvier exec -ti deploy/selma-deployment -- ./container-helper check

echo "## HOMER"
oc -n simpson exec -ti deploy/homer-deployment -- ./container-helper check

echo "## MARGE"
oc -n simpson exec -ti deploy/marge-deployment -- ./container-helper check
