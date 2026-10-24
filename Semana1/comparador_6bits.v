/* -----------------------------------------------------------------
 *  Arquivo   : comparador_6bits.v
 *  Projeto   : Fábula TEA
 * -----------------------------------------------------------------
 * Descricao : comparador de magnitude de 6 bits 
 *             similar ao CI 7485
 *             baseado em descricao comportamental disponivel em	
 * https://web.eecs.umich.edu/~jhayes/iscas.restore/74L85b.v
 * -----------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     14/03/2026  1.0     Fernando Ivanov   Criação
 * -----------------------------------------------------------------
 */

module comparador_6bits (ALBi, AGBi, AEBi, A, B, ALBo, AGBo, AEBo);

    input[5:0] A, B;
    input      ALBi, AGBi, AEBi;
    output     ALBo, AGBo, AEBo;
    wire[6:0]  CSL, CSG;

    assign CSL  = ~A + B + ALBi;
    assign ALBo = ~CSL[6];
    assign CSG  = A + ~B + AGBi;
    assign AGBo = ~CSG[6];
    assign AEBo = ((A == B) && AEBi);

endmodule 