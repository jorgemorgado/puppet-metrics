#!/usr/bin/env bash

# A few examples on how to use puppet-metrics
#
# ATTENTION: Do not run this without a *full review* of the commands below.
#
# Author: Jorge Morgado <jorge@morgado.ch>
#

# Your Puppet's codebase
PUPPET_DIR="/path/to/puppet/repository"

# Where to generate the statistics
BASE_DIR="/path/to/puppet-metrics"

# Where to find cloc and sqlite_formatter binaries
CLOC="/path/to/your/cloc"
SQLFMT="/path/to/your/sqlite_formatter"

# Where to find the JSON generator
GENJSON="/path/to/genjson.py"

# A name for your project
PROJECT="project_name"

# This will be appended to your stats files
DATE=`date +%Y%m%d`


# cloc arguments. Force 'pp' extension as Puppet manifests otherwise Pascal
# will be assumed.
CLOC_ARGS="--quiet --exclude-dir=.git --exclude-dir=.gitignore --force-lang=Puppet,pp"

# Should handle errors better because if these fail, nothing else works
[ -d "${BASE_DIR}" ]       || mkdir -p -m0755 "${BASE_DIR}"
[ -d "${BASE_DIR}/db" ]    || mkdir    -m0755 "${BASE_DIR}/db"
[ -d "${BASE_DIR}/stats" ] || mkdir    -m0755 "${BASE_DIR}/stats"
[ -d "${BASE_DIR}/www" ]   || mkdir    -m0755 "${BASE_DIR}/www"


#-----------------------------------------------------------------------------
# NOTE: The examples below separate files per $DATE. If you prefer to collect
# all statistics inside the same file (specially for the SQLite database),
# you need to adjust the commands/queries.
#-----------------------------------------------------------------------------

# Database file for today's project
DBFILE="${BASE_DIR}/db/${PROJECT}_${DATE}.db"

# Stats and web directories
STATS_DIR="${BASE_DIR}/stats"
WWW_DIR="${BASE_DIR}/www"


# Statistics per language
${CLOC} ${CLOC_ARGS} ${PUPPET_DIR} \
  > ${STATS_DIR}/language_${DATE}.txt

# Same as above but as percentage based on the value of
# code + comments + blanks denominator
${CLOC} ${CLOC_ARGS} --by-percent cmb ${PUPPET_DIR} \
  > ${STATS_DIR}/language_cmb_${DATE}.txt

# Say, you want to analyse only specific directories inside your code base
MYDIRS="/(hiera|modules)/"
${CLOC} ${CLOC_ARGS} --match-d="${MYDIRS}" ${PUPPET_DIR} \
  > ${STATS_DIR}/language_dir_${DATE}.txt

# Output the values count to SQLite database
${CLOC} ${CLOC_ARGS} --sql 1 --sql-project ${PROJECT} ${PUPPET_DIR} \
  | sqlite3 ${DBFILE}


# For all files in the database, strip the full path (you likely want this)
for f in `sqlite3 -noheader ${DBFILE} 'select file from t;' 2>/dev/null`; do
  newname=`echo ${f} | sed "s|^${PUPPET_DIR}|.|g"`
  sqlite3 ${DBFILE} "
    update t
    set file = '${newname}'
    where file = '${f}';" 2>/dev/null
done


# Which is the longest file?
sqlite3 ${DBFILE} '
  select project,file,nBlank+nComment+nCode as nL
  from t
  where nL = (select max(nBlank+nComment+nCode) from t)' \
  | ${SQLFMT}


# Which is the longest Puppet file?
sqlite3 ${DBFILE} '
  select project,file,nBlank+nComment+nCode as nL
  from t
  where language = "Puppet"
  and nL=(select max(nBlank+nComment+nCode) from t where language="Puppet")' \
  | ${SQLFMT}


# Which is the longest file in each project?
# (same as above if you keep one db for all projects)
sqlite3 ${DBFILE} '
  select project,file,max(nBlank+nComment+nCode) as nL
  from t
  group by project
  order by nL;' \
  | ${SQLFMT}


# Which files in each project have more LoC?
sqlite3 ${DBFILE} '
  select project,file,max(nCode) as nL
  from t
  group by project
  order by nL desc;' \
  | ${SQLFMT}


# Which Puppet files with more than 100 lines have a comment ratio below 10%?
sqlite3 ${DBFILE} '
  select file, nCode, nComment, (100.0*nComment)/(nComment+nCode) as comment_ratio
  from t
  where language = "Puppet"
    and nCode > 100
    and comment_ratio < 10
  order by comment_ratio;' 2>/dev/null \
  | ${SQLFMT} 2>/dev/null \
  > ${STATS_DIR}/files_comment_ratio_lt_10_${DATE}.txt


# What are the 50 longest files (based on LoC) that have no comments at all?
# Exclude Ruby templates and YAML files.
sqlite3 ${DBFILE} '
  select project, file, nCode, language
  from t
  where nComment = 0
    and language not in ("ERB", "YAML")
  order by nCode desc
  limit 50;' \
  | ${SQLFMT}


# What are the most popular languages (in terms of LoC) in each project?
sqlite3 ${DBFILE} '
  select language, sum(nCode) as SumCode
  from t
  group by language
  order by SumCode desc;' 2>/dev/null \
  | ${SQLFMT} 2>/dev/null \
  > ${STATS_DIR}/top_languages_${DATE}.txt


# Generate JSON for module by manifests LoC
JSON="manifest_by_loc"
sqlite3 ${DBFILE} '
  select file,nCode
  from t
  where file like "%/modules/%"
    and language = "Puppet"
  order by file;' 2>/dev/null \
  | ${GENJSON} \
  > ${WWW_DIR}/${JSON}_${DATE}.json

[ -L ${WWW_DIR}/${JSON}.json ] && rm -f ${WWW_DIR}/${JSON}.json
ln -s ${WWW_DIR}/${JSON}_${DATE}.json ${WWW_DIR}/${JSON}.json


# Generate JSON for module by manifests comments
JSON="manifest_by_comment"
sqlite3 ${DBFILE} '
  select file,nComment
  from t
  where file like "%/modules/%"
    and language = "Puppet"
  order by file;' 2>/dev/null \
  | ${GENJSON} \
  > ${WWW_DIR}/manifest_by_comment_${DATE}.json

[ -L ${WWW_DIR}/${JSON}.json ] && rm -f ${WWW_DIR}/${JSON}.json
ln -s ${WWW_DIR}/${JSON}_${DATE}.json ${WWW_DIR}/${JSON}.json


# Generate JSON for module by templates LoC
JSON="template_by_loc"
sqlite3 ${DBFILE} '
  select file,nCode
  from t
  where file like "%/modules/%"
    and language = "ERB"
  order by file;' 2>/dev/null \
  | ${GENJSON} \
  > ${WWW_DIR}/template_by_loc_${DATE}.json

[ -L ${WWW_DIR}/${JSON}.json ] && rm -f ${WWW_DIR}/${JSON}.json
ln -s ${WWW_DIR}/${JSON}_${DATE}.json ${WWW_DIR}/${JSON}.json


# Generate JSON for module by manifests + template LoC
JSON="manifest_templates_by_loc"
sqlite3 ${DBFILE} '
  select file,nCode
  from t
  where file like "%/modules/%"
    and language in ("ERB", "Puppet")
  order by file;' 2>/dev/null \
  | ${GENJSON} \
  > ${WWW_DIR}/manifest_templates_by_loc_${DATE}.json

[ -L ${WWW_DIR}/${JSON}.json ] && rm -f ${WWW_DIR}/${JSON}.json
ln -s ${WWW_DIR}/${JSON}_${DATE}.json ${WWW_DIR}/${JSON}.json
