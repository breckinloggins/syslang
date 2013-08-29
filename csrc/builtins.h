#ifndef BUILTINS_H
#define BUILTINS_H

/* prototypes */
#define BUILTIN(vector, word, type, immediate, fn) void builtin_##vector(struct env_t* env);
#include "builtins.h" /* nest x-macro include.  will declare prototypes */

/* TODO: this is a HACK */
#define builtin_execute   builtin_0
#define builtin_read_word builtin_2
#define builtin_call      builtin_4
#define builtin_number    builtin_8

void _builtin_binop(struct env_t* env, const char* word)
{
  struct word_trie_node_t* arg1 = stack_pop(env->stack, &env->stack_idx);
  struct word_trie_node_t* arg2 = stack_pop(env->stack, &env->stack_idx);

  if (arg1->type != node_number || arg2->type != node_number)  {
    DIE("at least one arg to word was not a number");
  }

  long res = 0;
  long n1 = (long)arg1->param->word;
  long n2 = (long)arg2->param->word;
  switch (word[0])  {
  case '+':
    res = n1 + n2;
    break;
  case '-':
    res = n1 - n2;
    break;
  case '*':
    res = n1 * n2;
    break;
  case '/':
    res = n1 / n2;
    break;
  case '%':
    res = n1 % n2;
    break;
  case '&':
    res = n1 & n2;
    break;
  case '|':
    res = n1 | n2;
    break;
  case '^':
    res = n1 ^ n2;
    break;
  default:
    DIE("internal compiler error - undefined binop");
  }

  char numstr[32];
  bzero(numstr, 32);
  numstr[0] = '\0';
  snprintf(numstr, 31, "%ld", res);

  struct word_trie_node_t* res_node = env_add(env, numstr);
  res_node->type = node_number;
  res_node->code = builtin_number;
  res_node->param = calloc(1, sizeof(struct word_ptr_node_t));
  res_node->param->word = (struct word_trie_node_t*)res;

  stack_push(env->stack, &env->stack_idx, res_node);
}

#else

/* 
 * The rest of this file will be included multiple times!
 */


BUILTIN(0, "execute", code, 0, {
  if (!env->ip) DIE("internal compiler error - no instruction pointer");

  if (env->mode == imode_interpret || env->ip->immediate) {
    env->ip->code(env);
  } else if (env->mode == imode_compile) {
    if (!env->compiling_word) DIE("internal compiler error - not compiling");

    struct word_ptr_node_t* last = env->compiling_word->param;
    struct word_ptr_node_t* prev = last;
    while (last && last->list_node.next)  {
      prev = last;
      last = (struct word_ptr_node_t*)last->list_node.next;
    }

    last = calloc(1, sizeof(struct word_ptr_node_t));
    if (!env->compiling_word->param)  {
      env->compiling_word->param = last;
    } else {
      prev->list_node.next = (struct list_node_t*)last;
    }

    last->word = env->ip;
  } else {
    DIE("internal compiler error - unimplemented compiler mode");
  }
})

BUILTIN(1, "words", code, 0, {
  char prefix[MAX_WORD_LEN];
  prefix[0] = '\0';
  word_trie_print_words(env->dictionary, prefix);
  fprintf(stderr, "\n");
})

BUILTIN(2, "read_word", code, 0, {
  int ch = 0;

  bzero(env->cur_word, MAX_WORD_LEN + 1);
  env->cur_word_idx = 0;
  while ((ch = getchar()) != EOF)  {
    if (isspace(ch))  {
      if (!env->cur_word_idx)  continue;
      return; 
    }

    if (env->cur_word_idx >= MAX_WORD_LEN) DIE("Word is too long");

    env->cur_word[env->cur_word_idx++] = ch;
  }

  if (ch == EOF) exit(0);
})

BUILTIN(3, "bye", code, 0, {
  exit(0);
})

BUILTIN(4, "call", code, 0, {
  /* like execute but saves the call stack */
  stack_push(env->rstack, &env->rstack_idx, env->ip);
  struct word_ptr_node_t* p = env->ip->param;
  while (p) {
    env->ip = p->word;
    builtin_execute(env); 
    p = (struct word_ptr_node_t*)p->list_node.next;
  }
  
  env->ip = stack_pop(env->rstack, &env->rstack_idx);
})

BUILTIN(5, ":", code, 0, {
  builtin_read_word(env);
  env->compiling_word = env_add(env, env->cur_word);
  env->compiling_word->type = node_normal;
  env->compiling_word->code = builtin_call;
  env->mode = imode_compile;
})

BUILTIN(6, ";", code, 1, { 
  env->compiling_word = 0; 
  env->mode = imode_interpret;
})

BUILTIN(7, ".", code, 0, {
  struct word_trie_node_t* node = stack_pop(env->stack, &env->stack_idx);
  switch (node->type) {
  case node_code:
    fprintf(stderr, "<code>\n");
    break;
  case node_normal:
    fprintf(stderr, "<normal>\n");
    break;
  case node_number:
    fprintf(stderr, "%ld\n", (long)node->param->word);
    break;
  default:
    fprintf(stderr, "<unknown>\n");
  }
})

BUILTIN(8, "number", code, 0, {
    // TODO: should probably be push self instead of this
    stack_push(env->stack, &env->stack_idx, env->ip);
})

BUILTIN(9, "_dbg", code, 0, {
  word_trie_print(env->dictionary, 0, stderr);
})

BUILTIN(10, ".s", code, 0, {
  fprintf(stderr, "%d> ", STACK_SIZE - env->stack_idx);
  for (int i = 0; i < STACK_SIZE - env->stack_idx; i++)  {
    struct word_trie_node_t* node = env->stack[env->stack_idx + i];
    switch (node->type) {
    case node_number:
      fprintf(stderr, "%ld ", (long)node->param->word);
      break;
    default:
      fprintf(stderr, "? ");
    }
  }
  fprintf(stderr, "\n");
})

/* TODO: Define the operations themselves here as well */
#define BINOP(vec, op) BUILTIN(vec, op, code, 0, { _builtin_binop(env, word); })
BINOP(11, "+")
BINOP(12, "-")
BINOP(13, "*")
BINOP(14, "/")
BINOP(15, "%")
BINOP(16, "&")
BINOP(17, "|")
BINOP(18, "^")

#undef BUILTIN
#endif // BULTINS_H
