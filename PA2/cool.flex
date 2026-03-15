/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
static int comment_depth = 0;
static const char *string_error_msg = 0;
static char invalid_char_buf[2] = {'\0', '\0'};

static int emit_error(const char *msg);
static int emit_invalid_char(int ch);
static void reset_string();
static void enter_string_error(const char *msg);
static void append_string_char(char ch);
static void append_string_text(const char *text, int length);
static int finish_string();
static int finish_string_error();

%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
ASSIGN          <-
LE              <=
WHITESPACE      [ \f\r\t\v]+
NEWLINE         \n
DIGIT           [0-9]
TYPE_ID         [A-Z][A-Za-z0-9_]*
OBJECT_ID       [a-z][A-Za-z0-9_]*
INTEGER         {DIGIT}+

CLASS_KW        [cC][lL][aA][sS][sS]
ELSE_KW         [eE][lL][sS][eE]
FI_KW           [fF][iI]
IF_KW           [iI][fF]
IN_KW           [iI][nN]
INHERITS_KW     [iI][nN][hH][eE][rR][iI][tT][sS]
LET_KW          [lL][eE][tT]
LOOP_KW         [lL][oO][oO][pP]
POOL_KW         [pP][oO][oO][lL]
THEN_KW         [tT][hH][eE][nN]
WHILE_KW        [wW][hH][iI][lL][eE]
CASE_KW         [cC][aA][sS][eE]
ESAC_KW         [eE][sS][aA][cC]
OF_KW           [oO][fF]
NEW_KW          [nN][eE][wW]
ISVOID_KW       [iI][sS][vV][oO][iI][dD]
NOT_KW          [nN][oO][tT]
TRUE_KW         t[rR][uU][eE]
FALSE_KW        f[aA][lL][sS][eE]

%option noyywrap
%x COMMENT STRING STRING_ERROR

%%

 /*
  *  Nested comments
  */
{NEWLINE}		{ curr_lineno++; }
{WHITESPACE}		{ }
"--"[^\n]*		{ }
"*)"			{ return emit_error("Unmatched *)"); }
"(*"			{ comment_depth = 1; BEGIN(COMMENT); }

<COMMENT>"(*"		{ comment_depth++; }
<COMMENT>"*)"		{
			  comment_depth--;
			  if (comment_depth == 0) {
				BEGIN(INITIAL);
			  }
			}
<COMMENT>{NEWLINE}	{ curr_lineno++; }
<COMMENT>\0		{ }
<COMMENT>.		{ }
<COMMENT><<EOF>>	{
			  BEGIN(INITIAL);
			  return emit_error("EOF in comment");
			}

 /*
  *  The multiple-character operators.
  */
{DARROW}		{ return (DARROW); }
{ASSIGN}		{ return (ASSIGN); }
{LE}			{ return (LE); }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
{CLASS_KW}		{ return (CLASS); }
{ELSE_KW}		{ return (ELSE); }
{FI_KW}		{ return (FI); }
{IF_KW}		{ return (IF); }
{INHERITS_KW}		{ return (INHERITS); }
{IN_KW}		{ return (IN); }
{LET_KW}		{ return (LET); }
{LOOP_KW}		{ return (LOOP); }
{POOL_KW}		{ return (POOL); }
{THEN_KW}		{ return (THEN); }
{WHILE_KW}		{ return (WHILE); }
{CASE_KW}		{ return (CASE); }
{ESAC_KW}		{ return (ESAC); }
{OF_KW}		{ return (OF); }
{NEW_KW}		{ return (NEW); }
{ISVOID_KW}		{ return (ISVOID); }
{NOT_KW}		{ return (NOT); }
{TRUE_KW}		{
			  cool_yylval.boolean = 1;
			  return (BOOL_CONST);
			}
{FALSE_KW}		{
			  cool_yylval.boolean = 0;
			  return (BOOL_CONST);
			}

{INTEGER}		{
			  cool_yylval.symbol = inttable.add_string(yytext);
			  return (INT_CONST);
			}
{TYPE_ID}		{
			  cool_yylval.symbol = idtable.add_string(yytext);
			  return (TYPEID);
			}
{OBJECT_ID}		{
			  cool_yylval.symbol = idtable.add_string(yytext);
			  return (OBJECTID);
			}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
"\""			{
			  reset_string();
			  BEGIN(STRING);
			}

<STRING>"\""		{ return finish_string(); }
<STRING>\0		{ enter_string_error("String contains null character"); }
<STRING>{NEWLINE}	{
			  curr_lineno++;
			  BEGIN(INITIAL);
			  return emit_error("Unterminated string constant");
			}
<STRING><<EOF>>		{
			  BEGIN(INITIAL);
			  return emit_error("EOF in string constant");
			}
<STRING>\\n		{ append_string_char('\n'); }
<STRING>\\t		{ append_string_char('\t'); }
<STRING>\\b		{ append_string_char('\b'); }
<STRING>\\f		{ append_string_char('\f'); }
<STRING>\\{NEWLINE}	{
			  curr_lineno++;
			  append_string_char('\n');
			}
<STRING>\\.		{ append_string_char(yytext[1]); }
<STRING>[^\\\"\n\0]+	{ append_string_text(yytext, yyleng); }

<STRING_ERROR>"\""	{ return finish_string_error(); }
<STRING_ERROR>{NEWLINE}	{
			  curr_lineno++;
			  BEGIN(INITIAL);
			  return emit_error(string_error_msg);
			}
<STRING_ERROR><<EOF>>	{
			  BEGIN(INITIAL);
			  return emit_error("EOF in string constant");
			}
<STRING_ERROR>\\{NEWLINE} { curr_lineno++; }
<STRING_ERROR>\\.	{ }
<STRING_ERROR>\0	{ }
<STRING_ERROR>[^\\\"\n\0]+ { }

"+"			{ return '+'; }
"/"			{ return '/'; }
"-"			{ return '-'; }
"*"			{ return '*'; }
"="			{ return '='; }
"<"			{ return '<'; }
"."			{ return '.'; }
"~"			{ return '~'; }
","			{ return ','; }
";"			{ return ';'; }
":"			{ return ':'; }
"("			{ return '('; }
")"			{ return ')'; }
"@"			{ return '@'; }
"{"			{ return '{'; }
"}"			{ return '}'; }
\0			{ return emit_invalid_char(0); }
.			{ return emit_invalid_char(yytext[0]); }

%%
static int emit_error(const char *msg) {
	cool_yylval.error_msg = const_cast<char *>(msg);
	return ERROR;
}

static int emit_invalid_char(int ch) {
	if (ch == 0) {
		invalid_char_buf[0] = '\0';
	} else {
		invalid_char_buf[0] = static_cast<char>(ch);
		invalid_char_buf[1] = '\0';
	}
	cool_yylval.error_msg = invalid_char_buf;
	return ERROR;
}

static void reset_string() {
	string_buf_ptr = string_buf;
	string_error_msg = 0;
}

static void enter_string_error(const char *msg) {
	string_error_msg = msg;
	BEGIN(STRING_ERROR);
}

static void append_string_char(char ch) {
	if (string_error_msg != 0) {
		return;
	}

	if (string_buf_ptr - string_buf >= MAX_STR_CONST - 1) {
		enter_string_error("String constant too long");
		return;
	}

	*string_buf_ptr++ = ch;
}

static void append_string_text(const char *text, int length) {
	for (int i = 0; i < length; ++i) {
		append_string_char(text[i]);
		if (string_error_msg != 0) {
			return;
		}
	}
}

static int finish_string() {
	*string_buf_ptr = '\0';
	cool_yylval.symbol = stringtable.add_string(string_buf);
	BEGIN(INITIAL);
	return STR_CONST;
}

static int finish_string_error() {
	BEGIN(INITIAL);
	return emit_error(string_error_msg);
}
