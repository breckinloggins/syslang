public void InitializeBuiltins(ArrayList<Word> dictionary)  {
  for (String name : new String[]{"words", "execute", ".", "+", "*"})  {
    dictionary.add(new Word(name, Word.WT_PRIMITIVE)); 
  }
}
  
public class Word {
  public static final int WT_PRIMITIVE = 0;
  public static final int WT_COMPILED = 1;
  
  public String name;
  public int type;
  public boolean immediate;
  public ArrayList<Integer> params;
  
  Word(String name, int type)  {
    this.name = name;
    this.type = type;
    this.immediate = false;
    if (type == WT_COMPILED)  {
      this.params = new ArrayList<Integer>(); 
    }
  }
  
  public void execute(Machine m)  {
    try  {
      if (type == WT_COMPILED)  {
        for (int i = 0; i < params.size(); i++)  {
          int idx = params.get(i);
          if (idx < 0 || idx >= m.dictionary.size())  {
            throw new SyslangException("invalid word address " + idx); 
          }
          Word w = m.dictionary.get(idx);
          w.execute(m);
        }
      } else if (name.equals("words"))  {
        for (int i = 0; i < m.dictionary.size(); i++)  {
          m.term.println("[" + i + "] " + m.dictionary.get(i).name); 
        }
      } else if (name.equals("execute"))  {
        int idx = m.ds.pop();
        if (idx < 0 || idx >= m.dictionary.size())  {
          throw new SyslangException("invalid word address"); 
        }
        
        Word w = m.dictionary.get(idx);
        w.execute(m);
      } else if (name.equals("."))  {
        m.term.println("" + m.ds.pop());
      } else if (name.equals("+")) {
        int a1 = m.ds.pop();
        int a2 = m.ds.pop();
        m.ds.push(a1 + a2);
      } else if (name.equals("*")) {
        int a1 = m.ds.pop();
        int a2 = m.ds.pop();
        m.ds.push(a1 * a2);
      } else {
        m.term.println("error: " + name + " does not have defined execution semantics");
      }
    } catch (SyslangException ex)  {
      m.term.println("error executing " + name + ": " + ex.getMessage()); 
    } 
  }
}
