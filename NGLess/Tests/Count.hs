{-# LANGUAGE TemplateHaskell, QuasiQuotes #-}
module Tests.Count
    ( tgroup_Count
    ) where

import Test.Framework.TH
import Test.HUnit
import Test.Framework.Providers.HUnit

import qualified Data.IntervalMap.Strict as IM
import qualified Data.Set as S
import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as B8
import qualified Data.Vector as V
import qualified Data.Map as M

import qualified Data.Conduit.Combinators as C
import qualified Data.Conduit.Binary as CB
import qualified Data.Conduit.List as CL
import qualified Data.Conduit as C
import           Data.Conduit ((=$=), ($$))
import           Control.Monad.Trans.Resource (runResourceT)
import Control.Monad.IO.Class (liftIO)
import Data.Maybe

import qualified Data.GFF as GFF
import Interpretation.Count
import Tests.Utils
import Data.GFF
import Utils.Here
import NGLess


tgroup_Count = $(testGroupGenerator)


readCountFile :: FilePath -> IO (M.Map B.ByteString Double)
readCountFile fp =
    runResourceT $
        C.sourceFile fp
            =$= CB.lines
            =$= (C.await >> (C.awaitForever C.yield)) -- skip first line
            $$ CL.foldMap parseLine
    where
        parseLine line = case B8.split '\t' line of
            [h,val] -> M.singleton h (read $ B8.unpack val)
            _ -> error ("Could not parse line: " ++ show line)


runSamGffAnnotation:: B.ByteString -> B.ByteString -> CountOpts -> NGLessIO (M.Map B.ByteString Double)
runSamGffAnnotation sam_content gff_content opts = do
    sam_fp <- asTempFile sam_content "sam"
    gff_fp <- asTempFile gff_content "gff"
    ann <- loadAnnotator (AnnotateGFF gff_fp) opts
    p <- performCount sam_fp "testing" ann opts
    liftIO $ readCountFile p


gff_structure_Exon = GFF.GffLine "chrI" "unknown" GFF.GffExon 4124 4358 Nothing GFF.GffNegStrand (-1) "gene_id \"Y74C9A.3\"; transcript_id \"NM_058260\"; gene_name \"Y74C9A.3\"; p_id \"P23728\"; tss_id \"TSS14501\";"
gff_structure_CDS = GFF.GffLine "chrI" "unknown" GFF.GffCDS 4124 4358 Nothing GFF.GffNegStrand (-1) "gene_id \"Y74C9A.3\"; transcript_id \"NM_058260\"; gene_name \"Y74C9A.3\"; p_id \"P23728\"; tss_id \"TSS14501\";"
gff_structure_Gene = GFF.GffLine "chrI" "unknown" GFF.GffGene 4124 4358 Nothing GFF.GffNegStrand (-1) "gene_id \"Y74C9A.3\"; transcript_id \"NM_058260\"; gene_name \"Y74C9A.3\"; p_id \"P23728\"; tss_id \"TSS14501\";"


gff_features_all = [GFF.GffGene, GFF.GffCDS, GFF.GffExon]
gff_features_gene = [GFF.GffGene]
gff_features_cds = [GFF.GffCDS]

gff_lines_ex = [gff_structure_Exon,gff_structure_CDS,gff_structure_Gene]

case_filter_features_1 = filter (matchFeatures gff_features_all) gff_lines_ex @?= gff_lines_ex
case_filter_features_2 = filter (matchFeatures [GFF.GffGene]) gff_lines_ex @?= [gff_structure_Gene]
case_filter_features_3 = filter (matchFeatures gff_features_gene) gff_lines_ex @?= [gff_structure_Gene]
case_filter_features_4 = filter (matchFeatures gff_features_cds) gff_lines_ex @?= [gff_structure_CDS]
case_filter_features_5 = filter (matchFeatures gff_features_cds) [gff_structure_Exon,gff_structure_Exon,gff_structure_Gene] @?= []

listNub = S.toList . S.fromList


defCountOpts =
    CountOpts
    { optFeatures = []
    , optIntersectMode = annotationRule IntersectUnion
    , optStrandSpecific = False
    , optMinCount = 0.0
    , optMMMethod = MMUniqueOnly
    , optDelim = "\t"
    , optNormSize = False
    }


very_short_gff = "test_samples/very_short.gtf"
case_load_very_short = do
    GFFAnnotator immap headers szmap <- testNGLessIO
                $ loadAnnotator (AnnotateGFF very_short_gff) defCountOpts  { optFeatures = [GffGene] }
    let usedIDs = map snd $ concat $ concatMap IM.elems $ M.elems immap
    length (listNub usedIDs ) @?= length headers
    minimum usedIDs @?= 0
    maximum usedIDs @?= length headers - 1
    M.size szmap @?= length headers
    M.lookup "WBGene00010199" szmap @?= Just (721-119+1)


short3 :: B.ByteString
short3 = [here|
V	protein_coding	gene	7322	8892	.	-	.	gene_id "WBGene00008825"; gene_name "F14H3.6"; gene_source "ensembl"; gene_biotype "protein_coding";
X	protein_coding	gene	140	218	.	+	.	gene_id "WBGene00020330"; gene_name "T07H6.1"; gene_source "ensembl"; gene_biotype "protein_coding";
X	protein_coding	gene	632	733	.	+	.	gene_id "WBGene00000526"; gene_name "clc-5"; gene_source "ensembl"; gene_biotype "protein_coding";
|]

-- this is a regression test
case_load_gff_order = do
    fp <- testNGLessIO $ asTempFile short3 "gtf"
    GFFAnnotator immap headers szmap <- testNGLessIO
                $ loadAnnotator (AnnotateGFF fp) defCountOpts  { optFeatures = [GffGene] }
    let [h] = map snd . concat . IM.elems  . fromJust $ M.lookup "V" immap
    (headers !! h) @?= "WBGene00008825"

short1 :: B.ByteString
short1 = [here|
X	protein_coding	gene	610	1473	.	+	.	gene_id "WBGene00002254"; gene_name "lbp-2"; gene_source "ensembl"; gene_biotype "protein_coding";
|]

short_sam :: B.ByteString
short_sam = [here|
@SQ	SN:X	LN:18942
SRR070372.1096	0	X	1174	60	62S75M1D37M46D58M10S	*	0	0	GTTCTACAACGTCCAGATCGGAAGCAAGTTCGAAGGAGAGGGTCTTGATAACACCAAGCACGAGGTTACCTTCACTCTCAAGGACGGACACTTGTTCGAACATCACAAGCCACTTGAAGAGGGAGAATCCAAGGAAGAACCTATGAGTATTACTTTGATGGAGATTTTCTTATTCAGAAGATGAGCTTCAACAATATCGAAGGCCGCAGATTCTACAAGAGACTCCCATAAAGTTAACTATC	IIIIIIF@@@CIIIIIIIIIIIIIIIIIIIIIHHIIIB=5669CIIIIIIIIIIIIIIIIIIIIIIIIIIHHHIHIIIIIIIIIIIIIIIIIIIHIIIIIIIIIIIIIIIHIH>>>FIIGBB@E??;75444<<:62///1>?BAAAD?AE;72217<AAAA;=/1117//7AADACDDGIEEEEEGGHGD@@@GGGGD@@@@DD@@@DDEBCBEBB@:566?6333;C@@=BAA:?E9911	NM:i:47	MD:Z:75^A37^CAGGTAAAATTTGGTCAATCTATTTGACATACATTTTTGTTAATTA58	AS:i:111	XS:i:19	SA:Z:X,1053,+,7M3D59M176S,60,3;
SRR070372.1096	2048	X	1053	60	7M3D59M176H	*	0	0	GTTCTACAACGTCCAGATCGGAAGCAAGTTCGAAGGAGAGGGTCTTGATAACACCAAGCACGAGGT	IIIIIIF@@@CIIIIIIIIIIIIIIIIIIIIIHHIIIB=5669CIIIIIIIIIIIIIIIIIIIIII	NM:i:3	MD:Z:7^AAA59	AS:i:59	XS:i:0	SA:Z:X,1174,+,62S75M1D37M46D58M10S,60,47;
SRR070372.1334	0	X	1174	60	61S75M1D16M1D10M1D9M46D55M1D7M1D6M1D10M1D5M2D25M2D11M2D16M	*	0	0	GTTCTACAACGTCCAGATCGGAAGCAAGTTCGAAGGAGAGGTCTTGATAACACCAAGCACGAGGTTACCTTCACTCTCAAGGACGGACACTTGTTCGAACATCACAAGCCACTTGAAGAGGGAGAATCCAAGGAAGAACCTATGAGTATTACTTGATGGAGATTTCTTATTCAGAAGATGAGCTTCAACAATATCGAAGGCCGCAGATTCTACAAGAGACTCCCATAAAGTTTAACTTATCTATTGAAATTTCTAAATTGCAATTCAATTTCATTTCCGAAAAATAAATTATTTCAAGCAATCTTC	IIIIIII???GIIIIIIIICCCCIIIIIIIIIIIIIIB?555?IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIICCCIIIICCBBBBB?;;6688EEEEGEIE:::?<<?CGEDDEEBBCC44:EIIIEEEIIIIGHGGGHGGIIIIIIEGCCCCEEIIIIICC?<?EEEG?AAEB1//5=<52.---,.=../,34A?CB<<<4777/222;;@@DDDAEEEEEBGA74496:,,,,,.,,,--.221326::477<BEE	NM:i:61	MD:Z:75^A16^T10^T9^CAGGTAAAATTTGGTCAATCTATTTGACATACATTTTTGTTAATTA55^A7^A6^T10^T5^TA2T22^AA11^TA0T15	AS:i:110	XS:i:20	SA:Z:X,1053,+,7M3D32M1D26M241S,60,4;
SRR070372.1334	2048	X	1053	60	7M3D32M1D26M241H	*	0	0	GTTCTACAACGTCCAGATCGGAAGCAAGTTCGAAGGAGAGGTCTTGATAACACCAAGCACGAGGT	IIIIIII???GIIIIIIIICCCCIIIIIIIIIIIIIIB?555?IIIIIIIIIIIIIIIIIIIIII	NM:i:4	MD:Z:7^AAA32^G26	AS:i:51	XS:i:0	SA:Z:X,1174,+,61S75M1D16M1D10M1D9M46D55M1D7M1D6M1D10M1D5M2D25M2D11M2D16M,60,61;
|]

case_count_two = do
    c <- testNGLessIO $ do
        let opts = defCountOpts { optFeatures = [GffGene] }
        gff <- asTempFile short1 "gff"
        samf <- asTempFile short_sam "sam"
        ann <- loadAnnotator (AnnotateGFF gff) opts
        cfp <- performCount samf "testing" ann opts
        liftIO (readCountFile cfp)
    c @?= M.fromList [("WBGene00002254", 2)]

sam1 = [here|
@SQ	SN:X	LN:10000
Read1	0	X	200	60	35M	*	0	0	CAATTGGAGTGCATCAAGTGGTGCGATAAGGTCCTA	22777449446411100.,,,1.11..0000,,,,	NM:i:51		AS:i:430	XS:i:19
|]
sam1neg = [here|
@SQ	SN:X	LN:10000
Read1	16	X	200	60	35M	*	0	0	CAATTGGAGTGCATCAAGTGGTGCGATAAGGTCCTA	22777449446411100.,,,1.11..0000,,,,	NM:i:51		AS:i:430	XS:i:19
|]

samPartial = [here|
@SQ	SN:X	LN:10000
Read1	0	X	80	60	35M	*	0	0	CAATTGGAGTGCATCAAGTGGTGCGATAAGGTCCTA	22777449446411100.,,,1.11..0000,,,,	NM:i:51		AS:i:430	XS:i:19
|]

samAmbiguous = [here|
@SQ	SN:X	LN:10000
Read1	0	X	280	60	35M	*	0	0	CAATTGGAGTGCATCAAGTGGTGCGATAAGGTCCTA	22777449446411100.,,,1.11..0000,,,,	NM:i:51		AS:i:430	XS:i:19
|]

samAmbiguous2 = [here|
@SQ	SN:X	LN:10000
Read1	0	X	280	60	35M	*	0	0	CAATTGGAGTGCATCAAGTGGTGCGATAAGGTCCTA	22777449446411100.,,,1.11..0000,,,,	NM:i:51		AS:i:430	XS:i:19
Read2	0	X	100	60	35M	*	0	0	CAATTGGAGTGCATCAAGTGGTGCGATAAGGTCCTA	22777449446411100.,,,1.11..0000,,,,	NM:i:51		AS:i:430	XS:i:19
|]

samAmbiguous3 = [here|
@SQ	SN:X	LN:10000
Ambiguous	0	X	280	60	35M	*	0	0	CAATTGGAGTGCATCAAGTGGTGCGATAAGGTCCTA	22777449446411100.,,,1.11..0000,,,,	NM:i:51		AS:i:430	XS:i:19
Match100.1	0	X	100	60	35M	*	0	0	CAATTGGAGTGCATCAAGTGGTGCGATAAGGTCCTA	22777449446411100.,,,1.11..0000,,,,	NM:i:51		AS:i:430	XS:i:19
Match100.2	0	X	100	60	35M	*	0	0	CAATTGGAGTGCATCAAGTGGTGCGATAAGGTCCTA	22777449446411100.,,,1.11..0000,,,,	NM:i:51		AS:i:430	XS:i:19
Match100.3	0	X	100	60	35M	*	0	0	CAATTGGAGTGCATCAAGTGGTGCGATAAGGTCCTA	22777449446411100.,,,1.11..0000,,,,	NM:i:51		AS:i:430	XS:i:19
Match300.1	0	X	420	60	35M	*	0	0	CAATTGGAGTGCATCAAGTGGTGCGATAAGGTCCTA	22777449446411100.,,,1.11..0000,,,,	NM:i:51		AS:i:430	XS:i:19
|]

gff1 = [here|
X	protein_coding	gene	100	400	.	+	.	gene_id "Gene100"; gene_name "gene1"; gene_source "ensembl"; gene_biotype "protein_coding";
X	protein_coding	gene	300	600	.	+	.	gene_id "Gene300"; gene_name "gene2"; gene_source "ensembl"; gene_biotype "protein_coding";
|]

case_gff_match = do
    c <- testNGLessIO $ runSamGffAnnotation sam1 gff1 defCountOpts { optFeatures = [GffGene] }
    c @?= M.fromList [("Gene100", 1), ("Gene300", 0)]

case_gff_strand_check = do
    c <- testNGLessIO $ runSamGffAnnotation sam1 gff1 defCountOpts { optFeatures = [GffGene], optStrandSpecific = True }
    c @?= M.fromList [("Gene100", 1), ("Gene300", 0)]

case_gff_strand_check_negstrand = do
    c <- testNGLessIO $ runSamGffAnnotation sam1neg gff1 defCountOpts { optFeatures = [GffGene], optStrandSpecific = True }
    c @?= M.fromList [("Gene100", 0), ("Gene300", 0)]

case_gff_feature_mismatch = do
    c <- testNGLessIO $ runSamGffAnnotation sam1 gff1 defCountOpts { optFeatures  = [GffCDS] }
    c @?= M.fromList []

case_gff_feature_partial = do
    c <- testNGLessIO $ runSamGffAnnotation samPartial gff1 defCountOpts { optFeatures  = [GffGene] }
    c @?= M.fromList [("Gene100", 1), ("Gene300", 0)]

case_gff_feature_partial_intersect = do
    c <- testNGLessIO $ runSamGffAnnotation samPartial gff1 defCountOpts { optFeatures  = [GffGene], optIntersectMode = annotationRule IntersectUnion }
    c @?= M.fromList [("Gene100", 1), ("Gene300", 0)]

case_gff_feature_ambiguous = do
    c <- testNGLessIO $ runSamGffAnnotation samAmbiguous gff1 defCountOpts { optFeatures  = [GffGene], optMMMethod = MMCountAll }
    c @?= M.fromList [("Gene100", 1), ("Gene300", 1)]

case_gff_feature_ambiguous_discard = do
    c <- testNGLessIO $ runSamGffAnnotation samAmbiguous gff1 defCountOpts { optFeatures  = [GffGene] }
    c @?= M.fromList [("Gene100", 0), ("Gene300", 0)]

case_gff_1OverN = do
    c <- testNGLessIO $ runSamGffAnnotation samAmbiguous gff1 defCountOpts { optFeatures  = [GffGene], optMMMethod = MM1OverN }
    c @?= M.fromList [("Gene100", 0.5), ("Gene300", 0.5)]

case_gff_dist1_fallback = do
    c <- testNGLessIO $ runSamGffAnnotation samAmbiguous gff1 defCountOpts { optFeatures  = [GffGene], optMMMethod = MMDist1 }
    c @?= M.fromList [("Gene100", 0.5), ("Gene300", 0.5)]

case_gff_dist1_dist = do
    c <- testNGLessIO $ runSamGffAnnotation samAmbiguous2 gff1 defCountOpts { optFeatures  = [GffGene], optMMMethod = MMDist1 }
    c @?= M.fromList [("Gene100", 2.0), ("Gene300", 0.0)]

case_gff_dist1_dist1_to_4 = do
    c <- testNGLessIO $ runSamGffAnnotation samAmbiguous3 gff1 defCountOpts { optFeatures  = [GffGene], optMMMethod = MMDist1 }
    c @?= M.fromList [("Gene100", 3.75), ("Gene300", 1.25)]


simple_map = [here|
#gene	cog	ko	module
gene1	NOG318324	NA	NA	NA
gene2	COG2813	K00564	NA
|]

case_load_map = do
    GeneMapAnnotator nmap names <- testNGLessIO $ do
        map_fp <- asTempFile simple_map "map"
        loadFunctionalMap map_fp ["ko"]
    let Just [ix] = M.lookup "gene1" nmap
    rsiName (names V.! ix) @?= "NA"
