
#Start ElasticSearch Reindex Same Indices
#
#  Load the home .bashrc if it hasn't been included.
#  Note:  BASHRC_LOADED needs to be set in the .bashrc.
#  Use this piece of code before any other variables are set since
#  the code might override the .bashrc variables

if [ -f ~/.bashrc -a -z "$BASHRC_LOADED" ]
then
        . ~/.bashrc
fi

#  General variables
export ACCOUNT=`whoami`
export PGM=`basename $0`
export SERVER=`hostname`
export DATE=`date +%Y%m%d%H%M`
export OVERDIR="/opt/elasticsearch/scripts"
export TERM=linux
export http_proxy=
export https_proxy=
export ftp_proxy=

OVERRIDES()
{
#  There are two places where you can override the
#  variables.  Either at the environment test or dev level
#  -or- at the server level.  This allows us to keep generic
#  scripts but will accomodate upgrades.

if [ -f $OVERDIR/overrides.${ENV} ]
then
        . $OVERDIR/overrides.${ENV}
fi

if [ -f $OVERDIR/overrides.$SERVER ]
then
        . $OVERDIR/overrides.$SERVER
fi
}

#  Determine if we have the correct number of input variables
##if [ "$1" == "" ] || [ "$2" == "" ]; then
if [ $# -lt 3 ]
then
   echo "Usage: $PGM <sourcehost> <sourceport> <user> <pwd> <file_indices_list> <desthost> <destport>"
   echo "       Example: $PGM localhost 9200  index.txt"
   echo "       Example: $PGM localhost 9200  index.txt"
   exit 1
fi

#  Set the variables as appropriate for this  product
export ESJSON=tmp_reindex.json
export REMOTE_HOST=$1:$2
export PATTERN=$3
if [ "$4" == "" ]; then
  export LOCAL_HOST=$1:$2
else
  export LOCAL_HOST=$4:$5
fi

clear

echo "---------------------------- NOTICE ----------------------------------"
echo " Created  by : Hartfordfive "
echo " Modified by : Hariom Singh"
echo "Email : @c9hariom / hariom.1.singh.ext@nokia.com"
echo "----------------------------------------------------------------------"
sleep 5

##INDICES=$(curl -H'Content-Type: application/json' --silent "$REMOTE_HOST/_cat/indices/$PATTERN?h=index")

export INDICES=`cat $PATTERN`
export TOTAL_INCOMPLETE_INDICES=0
export TOTAL_INDICES=0
export TOTAL_DURATION=0
export INCOMPLETE_INDICES=()

for INDEX in $INDICES; do

  TOTAL_DOCS_REMOTE=$(curl -H 'Content-Type: application/json' --silent "http://@${REMOTE_HOST}/_cat/indices/${INDEX}?h=docs.count")
  echo "Attempting to re-indexing ${INDEX} (${TOTAL_DOCS_REMOTE} docs total) from remote ES server..."
  SECONDS=0


  echo Creating Input File called ${ESJSON} .........
  echo '{' > ${ESJSON}
  echo '"conflicts": "proceed",' >> ${ESJSON}
  echo '"source": {' >> ${ESJSON}
  echo '"remote": {' >> ${ESJSON}
  echo '"host": "http://'${REMOTE_HOST}'",' >> ${ESJSON}
  echo '"username": "'${ESUSER}'",' >> ${ESJSON}
  echo '"password": "'${ESPASSWORD}'"' >> ${ESJSON}
  echo '},' >> ${ESJSON}
  echo '"index": [' >> ${ESJSON}
  echo '"'${INDEX}'"' >> ${ESJSON}
  echo ']' >> ${ESJSON}
  echo '},' >> ${ESJSON}
  echo '"dest": {' >> ${ESJSON}
  echo '"index": "'${INDEX}-reindexed'"' >> ${ESJSON}
  echo '},' >> ${ESJSON}
  echo '"script": {' >> ${ESJSON}
  echo '"lang": "painless",' >> ${ESJSON}
  echo '    "source": "    ctx._source.type = ctx._type;\n    ctx._type = \"doc\";"' >> ${ESJSON}
  echo '}' >> ${ESJSON}
  echo '}' >> ${ESJSON}

  cat ${ESJSON}

  echo curl -H 'Content-Type: application/json' -XPOST "http://@${LOCAL_HOST}/_reindex?wait_for_completion=true&pretty=true" --data-binary @${ESJSON}
  curl -H 'Content-Type: application/json' -XPOST "http://@${LOCAL_HOST}/_reindex?wait_for_completion=true&pretty=true" --data-binary @${ESJSON}

  duration=${SECONDS}

  LOCAL_INDEX_EXISTS=$(curl -H 'Content-Type: application/json' -o /dev/null --silent --head --write-out '%{http_code}' "http://@${LOCAL_HOST}/${INDEX}")
  if [ "$LOCAL_INDEX_EXISTS" == "200" ]; then
    TOTAL_DOCS_REINDEXED=$(curl -H 'Content-Type: application/json' --silent "http://@$LOCAL_HOST/_cat/indices/$INDEX?h=docs.count")
  else
    TOTAL_DOCS_REINDEXED=0
  fi

  echo "    Re-indexing results:"
  echo "     -> Time taken: $(($duration / 60)) minutes and $(($duration % 60)) seconds"
  echo "     -> Docs indexed: $TOTAL_DOCS_REINDEXED out of $TOTAL_DOCS_REMOTE"
  echo ""

  TOTAL_DURATION=$(($TOTAL_DURATION+$duration))

  if [ "$TOTAL_DOCS_REMOTE" -ne "$TOTAL_DOCS_REINDEXED" ]; then
    TOTAL_INCOMPLETE_INDICES=$(($TOTAL_INCOMPLETE_INDICES+1))
    INCOMPLETE_INDICES+=($INDEX)
  fi

  TOTAL_INDICES=$((TOTAL_INDICES+1))

done

echo "---------------------- STATS --------------------------"
echo "Total Duration of Re-Indexing Process: $((TOTAL_DURATION / 60))m $((TOTAL_DURATION % 60))"
echo "Total Indices: $TOTAL_INDICES"
echo "Total Incomplete Re-Indexed Indices: $TOTAL_INCOMPLETE_INDICES"
if [ "$TOTAL_INCOMPLETE_INDICES" -ne "0" ]; then
  printf '%s\n' "${INCOMPLETE_INDICES[@]}"
fi
echo "-------------------------------------------------------"
echo ""
