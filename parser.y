%{
#include <stdio.h>
#include <string.h>
#include <err.h>
#include <sys/queue.h>

#include "lex.yy.h"
#include "parser_queues.h"
#include "mysh.h"

void yyerror(char *s);

extern char *yytext;
extern int lineno;

%}

%union{
    struct string_queue_head *sqh_ptr;     /* alias StringQueueHead */
    struct cmd_queue_head *cqh_ptr;        /* alias CmdQueueHead */
    struct command *cmdptr;
    struct command **cmdptrptr;
    char *charptr;
    int int_cmd;
}

%token SEMICOLON
%token <charptr> WORD
%token EOL
%token <int_cmd> INTERNAL
%token PIPE
%token LREDIR
%token RREDIR

%type <sqh_ptr> args_seq
%type <cqh_ptr> cmd_seq
%type <cmdptr> cmd
%type <charptr> cmd_name
%type <cmdptrptr> line

%destructor { destroy_cmd_queue($$); } cmd_seq

%%

start:	line 
	{ 
		exec_cmds($1);
		free($1);
	}

line:   EOL
	{ 
		$$ = NULL; 
	}
	|	cmd_seq SEMICOLON EOL
	{
		$$ = cmd_queue_to_array($1);
		shallow_destroy_cmd_queue($1);
	}
	|	cmd_seq EOL
	{
		$$ = cmd_queue_to_array($1);
		shallow_destroy_cmd_queue($1);
	}

cmd_seq: cmd
	{
		CmdQueueEntry *eptr = create_cmd_queue_entry($1);
		$$ = initialize_cmd_queue(eptr);
	}
	| cmd_seq SEMICOLON cmd
	{
		CmdQueueEntry *eptr = create_cmd_queue_entry($3);
		insert_cmd_queue($1, eptr);
		$$ = $1;
	}

cmd: cmd_name
	{
		struct command *cmdptr = malloc(sizeof(struct command));
		if (!cmdptr)
			err(1, "malloc");
		cmdptr->name = $1;
		cmdptr->args = NULL;
		cmdptr->executioner = general_executioner;
		$$ = cmdptr;
	}
	| cmd_name args_seq
	{
		struct command *cmdptr = malloc(sizeof(struct command));
		if (!cmdptr)
			err(1, "malloc");
		cmdptr->name = $1;
		cmdptr->args = string_queue_to_array($2);
		cmdptr->executioner = general_executioner;
		shallow_destroy_string_queue($2);
		$$ = cmdptr;
	}
	| INTERNAL
	{
		struct command *cmdptr = malloc(sizeof(struct command));
		if (!cmdptr)
			err(1, "malloc");
		cmdptr->args = NULL;
		switch ($1) {
			case CD:
				cmdptr->name = strdup("cd");
				if (!(cmdptr->name))
					err(1, "strdup");
				cmdptr->executioner = cd_executioner;
				break;
			case EXIT:
				cmdptr->name = strdup("exit");
				if (!(cmdptr->name))
					err(1, "strdup");
				cmdptr->executioner = exit_executioner;
				break;
		}
		$$ = cmdptr;
	}
	| INTERNAL args_seq
	{
		struct command *cmdptr = malloc(sizeof(struct command));
		if (!cmdptr)
			err(1, "malloc");
		cmdptr->args = string_queue_to_array($2);
		shallow_destroy_string_queue($2);
		switch ($1) {
			case CD:
				cmdptr->name = strdup("cd");
				if (!(cmdptr->name))
					err(1, "strdup");
				cmdptr->executioner = cd_executioner;
				break;
			case EXIT:
				cmdptr->name = strdup("exit");
				if (!(cmdptr->name))
					err(1, "strdup");
				cmdptr->executioner = exit_executioner;
				break;
		}
		$$ = cmdptr;
	}

cmd_name: WORD 
	{ 
		char *s = strdup($1);
		if (!s)
			err(1, "strdup");
		$$ = s; 
	}

args_seq: WORD  
	{ 
		char *s = strdup($1);
		if (!s)
			err(1, "strdup");
		StringQueueEntry *qeptr = create_string_queue_entry(s);
		$$ = initialize_string_queue(qeptr); 
	}
	| args_seq WORD 
	{ 
		char *s = strdup($2);
		if (!s)
			err(1, "strdup");
		StringQueueEntry *qeptr = create_string_queue_entry(s);
		insert_string_queue($1, qeptr);
		$$ = $1; 
	}

%%

void
yyerror(char *s)
{
	fprintf(stderr, "error:%d: %s near unexpected token '%s'\n", lineno, s, yytext);
	ret_val = 254;
}