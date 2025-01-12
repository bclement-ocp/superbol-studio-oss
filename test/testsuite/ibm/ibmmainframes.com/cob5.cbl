                            IDENTIFICATION DIVISION.
                            PROGRAM-ID. MACTIME.
                            DATA DIVISION.
                            WORKING-STORAGE SECTION.
                            01 ST.
                                     05 HH PIC 99.
                                     05 MM PIC 99.
                                     05 SS PIC 99.
                            01 PS PIC 9 VALUE 2.
                            01 NG PIC 9 VALUE 2.
                            01 XCH PIC 99 VALUE 01.
                            PROCEDURE DIVISION.
                            0001.
                                     DISPLAY "ENTER INDIA STANDARD TIME (HHMMSS /235959)".
                                     ACCEPT ST.
                                     IF ST = SPACE ACCEPT ST FROM TIME
                                     DISPLAY "YOUR SYSTEM TIME IS :- " HH ":" MM ":" SS
                                     ELSE DISPLAY "TIME ENTERED BY YOU :- " HH ":" MM ":" SS.
                                     DISPLAY "XCHOOSE THE COUNTRY YOU WANT TO XCHECK THE TIME NOW".
                                     DISPLAY "1.ARABIA            2.AUSTRALIA          3.ALGERIA     4.ALASKA".
                                     DISPLAY "5.BAHRAIN         6.BRASIL                 7.BELGIUM     8.XCHINA".
                                     DISPLAY "9.CANADA          10.CNTAMERIC      11.EGYPT        12.GREESE".
                                     DISPLAY "13.GERMANY    14.HONG KONG      15.IRAQ          16.JAPAN".
                                     DISPLAY "17.KENYA           18.LONDON             19.MEXICO    20.NEZEALND".
                                     DISPLAY "21.PAKISTN        22.RUSSIA                23.SPAIN        24.SOUTHAFRICA".
                                     DISPLAY "25.SRILANK       26.SYDNEY               27.SINGAPRE 28.ZIMBABWE".
                                     DISPLAY " ".
                                     PERFORM 0003 5 TIMES.
                                     DISPLAY "ENTER YOUR XCHOICE(2 DIGIT INTEGER)".
                                     ACCEPT XCH.
                                     IF XCH = 1 PERFORM 0002 4 TIMES DISPLAY "NOW ARABIAN TIME IS"
                                     ELSE IF XCH = 2 PERFORM 0002 10 TIMES DISPLAY "AUSTRALIA TIME"
                                     ELSE IF XCH = 3 DISPLAY "ALGERIAN TIME IS"
                                     ELSE IF XCH = 4 PERFORM 0003 9 TIMES DISPLAY "ALASKA TIME IS"
                                     ELSE IF XCH = 5 PERFORM 0002 3 TIMES DISPLAY "BAHRAIN TIME IS"
                                     ELSE IF XCH = 6 PERFORM 0003 3 TIMES DISPLAY "BRASIL TIME IS"
                                     ELSE IF XCH = 7 DISPLAY "BELGIUM TIME IS"
                                     ELSE IF XCH = 8 PERFORM 0002 8 TIMES DISPLAY "XCHINA TIME IS"
                                     ELSE IF XCH = 9 PERFORM 0003 8 TIMES DISPLAY "CANADA TIME IS"
                                     ELSE IF XCH = 10 PERFORM 0003 6 TIMES DISPLAY "CENTRL AMERIC"
                                     ELSE IF XCH = 11 PERFORM 0002 2 TIMES DISPLAY "EGYPT TIME IS"
                                     ELSE IF XCH = 12 PERFORM 0002 2 TIMES DISPLAY "GREESE TIME"
                                     ELSE IF XCH = 13 PERFORM 0002 1 TIMES DISPLAY "GERMANY TIME"
                                     ELSE IF XCH = 14 PERFORM 0002 8 TIMES DISPLAY "HONKKONG TIME"
                                     ELSE IF XCH = 15 PERFORM 0002 3 TIMES DISPLAY "IRAQ TIME IS"
                                     ELSE IF XCH = 16 PERFORM 0002 9 TIMES DISPLAY "JAPAN TIME IS"
                                     ELSE IF XCH = 17 PERFORM 0002 3 TIMES DISPLAY "KENYA TIME IS"
                                     ELSE IF XCH = 18 DISPLAY "LONDON TIME IS"
                                     ELSE IF XCH = 19 PERFORM 0003 6 TIMES DISPLAY "MEXICO TIME IS"
                                     ELSE IF XCH = 20 PERFORM 0002 2 TIMES DISPLAY "NEW ZEALAND:"
                                     ELSE IF XCH = 21 PERFORM 0002 5 TIMES DISPLAY "PAKISTAN TIME"
                                     ELSE IF XCH = 22 PERFORM 0002 13 TIMES DISPLAY "RUSSIA TIME IS"
                                     ELSE IF XCH = 23 PERFORM 0002 1 TIMES DISPLAY "SPAIN TIME IS"
                                     ELSE IF XCH = 24 PERFORM 0002 1 TIMES DISPLAY "SOUTH AFRICA: "
                                     ELSE IF XCH = 25 PERFORM 0002 5 TIMES DISPLAY "SRILANKA TIME"
                                     ELSE IF XCH = 26 PERFORM 0002 10 TIMES DISPLAY "SYDNEY TIME IS"
                                     ELSE IF XCH = 27 PERFORM 0002 8 TIMES DISPLAY "SINGAPORE TIME"
                                     ELSE IF XCH = 28 PERFORM 0002 2 TIMES DISPLAY "ZIMBABWE TIME"
                                     ELSE DISPLAY "INVALID KEY ENTERED" GO 0001.
                                     DISPLAY " ".
                                     IF PS = 1 DISPLAY "TOMORROW :-"
                                     ELSE IF NG = 1 DISPLAY "YESTERDAY :-".
                                     DISPLAY HH ":" MM ":" SS.
                                     STOP RUN.
                              0002.
                                     ADD 1 TO HH.
                                     IF HH = 24 COMPUTE HH = 00 MOVE 1 TO PS.
                              0003.
                                     SUBTRACT 1 FROM HH.
                                     IF HH = 00 COMPUTE HH = 24 MOVE 1 TO NG.
