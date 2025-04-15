'''
Created on May 17 2019
@author: Greg Salomons
A collection of tools for Varian Database Queries.
Functions
    connect(db_server='VARDBPV1', database='variansystem')->pyodbc.Cursor:
        Establishes a connection to a Varian database.
    run_query(cursor: pyodbc.Cursor, query_path: Path)->pd.DataFrame:
        Run a SQL query.
    create_output_file(file_name: str, base_dir=Path(r'.'))->xw.Book:
        Create an output spreadsheet.
'''


from os import stat
from pathlib import Path
from datetime import datetime, timedelta
from typing import Union, Tuple, Dict, List, NamedTuple
import pyodbc
import pandas as pd
import xlwings as xw

QueryOutput = Union[Dict[str, str], pd.DataFrame]

class DbGroup(NamedTuple):
    '''Definition parameters for a database connection.
    '''
    server: str    # The name of the server to connect to.
    database: str  # The name of the database on that server.
    db_source: str = 'ARIA'  # Annotation information, can be anything
    version: str = 'V15.6'  # Annotation information, can be anything


# Information required to establish a database connection.
# The parameters need to be set to match the local configuration.
# See the class DbGroup definition above for more information.
DB_GROUPS = {
    'V15 ARIA T-Box': DbGroup('ARIA-TBOX', 'VARIAN', 'ARIA', 'V15.6'),
    'V15 User T-Box': DbGroup('ARIA-TBOX', 'VAISUserServiceDb', 'ARIA', 'V15.6'),
    'V15 Connect T-Box': DbGroup('ARIA-TBOX', 'Monitoring', 'AURA', 'V15.6'),
    'V15 PlanningModel T-Box': DbGroup('ARIA-TBOX', 'PlanningModelLibrary', 'AURA', 'V15.6'),
    'V15 Expert T-Box': DbGroup('ARIA-TBOX', 'varianexpertlibrary', 'ARIA', 'V15.6'),
    'V15 Framework T-Box': DbGroup('ARIA-TBOX', 'VarianSharedFrameworkDatabase', 'ARIA', 'V15.6'),
    'V15 AURA T-Box': DbGroup('ARIA-TBOX', 'variandw', 'AURA', 'V15.6'),
    'V15 Reports T-Box': DbGroup('ARIA-TBOX', 'ReportServer', 'AURA', 'V15.6'),
    'V15 Reports': DbGroup('ARIADWPV1', 'ReportServer', 'AURA', 'V15.6'),
    'V15 AURA': DbGroup('ARIADWPV1', 'variandw', 'AURA', 'V15.6'),
    'V15 ARIA': DbGroup('ARIADBPV1', 'VARIAN', 'ARIA', 'V15.6'),
    'V15 Expert': DbGroup('ARIADBPV1', 'varianexpertlibrary', 'ARIA', 'V15.6')
   }


RGB = Tuple[int, int, int]
Line = Tuple[int, int, int, int]


def hex2parts(hex_pattern: bytes) -> Line:
    '''Convert a Hex pattern into 4 components.
    '''
    if hex_pattern:
        parts = list(bytearray(hex_pattern))
        pattern = tuple([parts[0], parts[1], parts[2], parts[3]])
    else:
        pattern = ('','','','')
    return pattern


def hex2rgb(hex_color: bytes) -> RGB:
    '''Convert a Hex colour into its RGB components.
    '''
    if hex_color:
        color_parts = list(bytearray(hex_color))
        rgb = str(tuple([color_parts[2], color_parts[1], color_parts[0]]))
    else:
        rgb = None
    return rgb

# Hospital ID is a 7 digit text string
def CR_num(x): return '{:07d}'.format(x)


def connect(db_server='ARIADBPV1', database='VARIAN', version='V15.6',
            time_out=0)->pyodbc.Connection:
    '''Establishes a connection to a Varian database.
    Arguments:
        db_server {str} -- The name of the Varian server.  One of:
            VARDBPV1, VAURAPV1  (Production)
            VARIANTV2, VARIANTV3 (V13 T Box)
            ARIA-TBOX, ARIA-TBOX2 (V15 T Box)
            Default is VARDBPV1
        database {str} -- The name of the database on the server.  One of:
            variandw, ReportServer (VAURAPV1)
            variansystem, varianenm (VARDBPV1)
            variandw, ReportServer, VARIAN (ARIA-TBOX)
            Default is variansystem
        Returns
            {pyodbc.Connection} connection to the selected database.
    '''
    connection_str = r'DRIVER={SQL Server}; '
    connection_str += r'SERVER={}; DATABASE={}'.format(db_server, database)
    if 'V13.6' in version:
        connection_str += r'; UID=reports; PWD=reports'
    connection = pyodbc.connect(connection_str, timeout=time_out)
    return connection


def make_connection(db_name: str, time_out=0)->pyodbc.Connection:
    '''Establishes a connection to a Varian database.
    Arguments:
        db_name {str} -- The name of one of the Varian DB_GROUPS.  One of:
            'V15 ARIA T-Box'
            'V15 User T-Box'
            'V15 Connect T-Box'
            'V15 PlanningModel T-Box'
            'V15 Expert T-Box'
            'V15 Framework T-Box'
            'V15 AURA T-Box'
            'V15 Reports T-Box'
            'V15 Reports'
            'V15 AURA'
            'V15 ARIA'
            'V15 Expert'
        Returns
            {pyodbc.Connection} connection to the selected database.
    '''
    db_group = DB_GROUPS[db_name]
    connection = connect(db_server=db_group.server,
                         database=db_group.database,
                         version=db_group.version,
                         time_out=time_out)
    return connection


def run_query(connection: pyodbc.Connection, query_path: Path,
              selection_criteria: Dict[str, str] = None)->pd.DataFrame:
    '''Run a SQL query.
    Arguments:
        connection {pyodbc.Connection} -- The connection to a Varian database.
        query_path {Path} -- Path to the file containing the SQL text.
        selection_criteria {Dict[str, str]} -- Query modifier using the .format
            command.
    Returns
        {pd.DataFrame} A Pandas DataFrame with the results of the query.
    '''
    cursor = connection.cursor()
    query_text = Path(query_path).read_text()
    if selection_criteria:
        query_text = query_text.format(**selection_criteria)
    cursor.execute(query_text)
    data = cursor.fetchall()
    if data:
        columns_names = [s[0] for s in data[0].cursor_description]
        query_result = pd.DataFrame([tuple(row) for row in data],
                                    columns=columns_names)
        return query_result
    return pd.DataFrame()


def query_dict(connection: pyodbc.Connection, query_path: Path,
               selection_criteria=None)->Dict[str, str]:
    '''Run a SQL query.
    Arguments:
        connection {pyodbc.Connection} -- The connection to a Varian database.
        query_path {Path} -- Path to the file containing the SQL text.
        selection_criteria {Dict[str, str]} -- Query modifier using the .format
            command.
    Returns
        {Dict[str, str]} Query results in the form of a dictionary.
    '''
    cursor = connection.cursor()
    query_text = Path(query_path).read_text()
    if selection_criteria:
        query_text = query_text.format(**selection_criteria)
    cursor.execute(query_text)
    data = cursor.fetchall()
    columns_names = [s[0] for s in data[0].cursor_description]
    query_result = list()
    for row in data:
        row_data = {name: data for name, data in zip(columns_names, row)}
        query_result.append(row_data)
    return query_result


def text_query(connection: pyodbc.Connection,
               query_text: str, selection_criteria=None,
               output_type='Dict')->QueryOutput:
    '''Run a SQL query with supplied SQL text.
    Arguments:
        connection {pyodbc.Connection} -- The connection to a Varian database.
        query_text {str} -- SQL query text.
        selection_criteria {Dict[str, str]} -- Query modifier using the .format
            command.
        output_type {str} -- Specifies the return data type.  One of 'Dict', 'DataFrame'.
            Default is 'Dict'.
    Returns
        {(List[Dict[str, str]], pd.DataFrame)} Query results in the form of a dictionary or DataFrame.
    '''
    if selection_criteria:
        query_text = query_text.format(**selection_criteria)
    cursor = connection.cursor()
    cursor.execute(query_text)
    data = cursor.fetchall()
    if not data:
        return []
    columns_names = [s[0] for s in data[0].cursor_description]
    if 'Dict' in output_type:
        query_result = list()
        for row in data:
            row_data = {name: data for name, data in zip(columns_names, row)}
            query_result.append(row_data)
    elif 'DataFrame' in output_type:
        query_result = pd.DataFrame([tuple(row) for row in data],
                                    columns=columns_names)
    else:
        msg= f'output_type {output_type} is not one of "Dict" or "DataFrame"'
        raise ValueError(msg)
    return query_result


def create_output_file()->xw.Book:
    '''Create an output spreadsheet.
    Returns
        {pd.DataFrame} A new blank spreadsheet to save the data in.
    '''
    exel_app = xw.apps.active
    if not exel_app:
        exel_app = xw.App(visible=None, add_book=False)
    output_file = exel_app.books.add()
    return output_file


def get_data_path(connection: pyodbc.Connection) -> Path:
    '''Build the full path to a database file reference.
    Arguments:
        connection {pyodbc.Connection} -- The connection to a Varian database.
    Returns
        {Path}  The path to the file data location.
    '''
    server_name = connection.getinfo(pyodbc.SQL_SERVER_NAME)
    if server_name in 'VARDBPV1':
        fileserver = 'varimgpv1'
    elif server_name in 'VARIANTV2':
        fileserver = 'variantv2'
    elif server_name in 'VARIANTV3':
        fileserver = 'variantv3'
    else:
        fileserver = '.'
    data_path = Path(r'\\{}\va_data$\Filedata'.format(fileserver))
    return data_path


def make_path(data_path: Path, file_name: str) -> str:
    '''Build the full path to a database file reference.
    Arguments:
        data_path {Path} -- The path to the file data location.
        file_name {str} -- The database file reference string.
    Returns
        {Path}   Full path to the referenced file.
    '''
    if file_name:
        full_file_name = file_name[2:].replace('IMAGEDIR1', str(data_path))
        full_file_name = full_file_name.replace('imagedir1', str(data_path))
        full_path = full_file_name
    else:
        full_path = None
    return full_path


def file_size(file_name: str)->int:
    '''Return the file size.
    '''
    if file_name:
        return stat(file_name).st_size
    return None


def file_modified(file_name: str)->datetime:
    '''Return the file modification time.
    '''
    if file_name and Path(file_name).exists():
        mod_seconds = stat(file_name).st_mtime
        mod_time = datetime.min + timedelta(seconds=mod_seconds)
        return str(mod_time)
    return None
