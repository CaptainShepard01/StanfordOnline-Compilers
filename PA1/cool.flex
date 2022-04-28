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

static int comments_stack;
static int null_char_present;
static std::string current_string;

%}

/*
 * Define names for regular expressions here.
 */

INTEGER	        	[[:digit:]]+
ESCAPE	        	\\
NEWLINE	        	\n
NULL_CHAR       	\0
SINGLE_CHAR_TOKENS	[:+\-*/=)(}{~.,;<@]
LPAREN	        	\(
RPAREN	        	\)
STAR	        	\*
ALPHANUM        	[[:alnum:]_]
TYPE_ID	        	[[:upper:]]{ALPHANUM}*
OBJECT_ID       	[[:lower:]]{ALPHANUM}*
QUOTE	        	\"
HYPHEN	        	-
WHITESPACE      	[ \t\r\f\v]
IF              	(?i:if)
FI              	(?i:fi)
TRUE            	t(?i:rue)
FALSE	        	f(?i:alse)
CLASS           	(?i:class)
ELSE            	(?i:else)
IN              	(?i:in)
INHERITS        	(?i:inherits)
ISVOID          	(?i:isvoid)
LET             	(?i:let)
LOOP            	(?i:loop)
POOL            	(?i:pool)
THEN            	(?i:then)
WHILE           	(?i:while)
CASE            	(?i:case)
ESAC            	(?i:esac)
NEW             	(?i:new)
OF              	(?i:of)
NOT             	(?i:not)
SELF            	self
SELF_TYPE       	SELF_TYPE
DARROW          	=>

%x COMMENTS COMMENT_IN_LINE STRING


%%

{DARROW}		{ return (DARROW); }

{SINGLE_CHAR_TOKENS} {
    return int(yytext[0]);
}

 /*
  *  The multiple-character operators.
  */

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

{CLASS}	    return CLASS;
{ELSE}    	return ELSE;
{FI}  		return FI;
{IF}      	return IF;
{IN}      	return IN;
{INHERITS}	return INHERITS;
{LET}     	return LET;
{LOOP}    	return LOOP;
{POOL}    	return POOL;
{THEN}    	return THEN;
{WHILE}	    return WHILE;
{CASE}	    return CASE;
{ESAC}  	return ESAC;
{OF}    	return OF;
{NEW}   	return NEW;
{ISVOID}	return ISVOID;
{NOT}   	return NOT;
"<="		return LE;
"<-"		return ASSIGN;

{WHITESPACE} ;

{HYPHEN}{HYPHEN} {
    BEGIN COMMENT_IN_LINE;
}

{NEWLINE}	curr_lineno++;

{TRUE}	{
    cool_yylval.boolean = 1;
    return BOOL_CONST;
}

{FALSE} {
    cool_yylval.boolean = 0;
    return BOOL_CONST;
}

{INTEGER} {
    cool_yylval.symbol = inttable.add_string(yytext);
    return INT_CONST;
}

{TYPE_ID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return TYPEID;
}

{OBJECT_ID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return OBJECTID;
}

{STAR}{RPAREN} {
    cool_yylval.error_msg = "Mismatched *)";
    return ERROR;
}

{LPAREN}{STAR} {
    comments_stack++;
    BEGIN COMMENTS;
}

{QUOTE}	{
    BEGIN STRING;
    current_string = "";
    null_char_present = 0;
}

. {
    cool_yylval.error_msg = yytext;
    return ERROR;
}

<COMMENT_IN_LINE>{NEWLINE} {
    curr_lineno++;
    BEGIN INITIAL;
}

<COMMENT_IN_LINE><<EOF>> {
    BEGIN INITIAL;
}

<COMMENT_IN_LINE>.	;

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for
  *  \n \t \b \f, the result is c.
  *
  */

<STRING>{QUOTE}	{
    BEGIN INITIAL;
    if (current_string.size() >= MAX_STR_CONST) {
        cool_yylval.error_msg = "String constant too long";
	    return ERROR;
    }
    if (null_char_present) {
        cool_yylval.error_msg = "String contains null character";
        return ERROR;
    }
    cool_yylval.symbol = stringtable.add_string((char *)current_string.c_str());
    return STR_CONST;
}

<STRING>{ESCAPE}{NEWLINE} {
    current_string += '\n';
}

<STRING>{NEWLINE} {
    BEGIN INITIAL;
    curr_lineno++;
    cool_yylval.error_msg = "Unterminated string constant";
    return ERROR;
}

<STRING>{NULL_CHAR} {
    null_char_present = 1;
}

<STRING>{ESCAPE}. {
    char ch;
    switch((ch = yytext[1])) {
        case 'b':
	    current_string += '\b';
	    break;
	case 't':
	    current_string += '\t';
	    break;
	case 'n':
	    current_string += '\n';
	    break;
	case 'f':
	    current_string += '\f';
	    break;
	case '\0':
	    null_char_present = 1;
	    break;
	default:
	    current_string += ch;
            break;
    }
}

<STRING><<EOF>> {
    BEGIN INITIAL;
    cool_yylval.error_msg = "EOF in string";
    return ERROR;
}

<STRING>. {
    current_string += yytext;
}

 /*
  *  Nested comments
  */

<COMMENTS>{LPAREN}{STAR} {
    comments_stack++;
}

<COMMENTS>{STAR}{RPAREN} {
    comments_stack--;
    if (comments_stack == 0) {
       BEGIN INITIAL;
    }
}

<COMMENTS>{NEWLINE} {
    curr_lineno++;
}

<COMMENTS><<EOF>> {
    BEGIN INITIAL;
    cool_yylval.error_msg = "EOF in comment";
    return ERROR;
}

<COMMENTS>.	;

%%

 /*
  *  User subroutines
  */
